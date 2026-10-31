"""The Echo Wall Clock's wire protocol, as an Echo speaks it.

Alexa Gadgets Toolkit over Classic Bluetooth (RFCOMM). Every message is a
protobuf "directive" (to the clock) or "event" (from it), in a frame:

    F0 | 02 | 00 | seq | payload | checksum (16 bit, big endian) | F1

with F0, F1 and F2 in payload and checksum escaped as F2, byte ^ F2. The
checksum is 0x02 + 0x00 + the sum of the unescaped payload bytes.

The clock decodes with fixed-size buffers: a directive header with anything but
namespace and name (a real Echo sends nothing else) is dropped silently, which
is why `directive()` never sets messageId or dialogRequestId.

No Home Assistant imports here.
"""

from __future__ import annotations

from collections.abc import Iterator
from dataclasses import dataclass, field
from datetime import datetime

SOF, EOF, ESC = 0xF0, 0xF1, 0xF2
PACKET_ID = 0x02
_SPECIAL = frozenset((SOF, EOF, ESC))

# Alerts.SetAlert types.
TIMER, ALARM, REMINDER = "TIMER", "ALARM", "REMINDER"
ALERT_TYPES = (TIMER, ALARM, REMINDER)


class ProtocolError(Exception):
    """A frame or message that can't be read."""


# --- protobuf, just enough of it --------------------------------------------

Field = tuple[int, "bytes | str | int | bool | list[Field] | None"]


def _varint(n: int) -> bytes:
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def encode(*fields: Field) -> bytes:
    """Encode `(number, value)` pairs; a list value is a nested message,
    None leaves the field out."""
    out = bytearray()
    for number, value in fields:
        if value is None:
            continue
        if isinstance(value, bool | int):
            out += _varint(number << 3) + _varint(int(value))
            continue
        if isinstance(value, str):
            value = value.encode()
        elif isinstance(value, list):
            value = encode(*value)
        out += _varint(number << 3 | 2) + _varint(len(value)) + value
    return bytes(out)


def _read_varint(buf: bytes, i: int) -> tuple[int, int]:
    n = shift = 0
    while True:
        if i >= len(buf):
            raise ProtocolError("truncated varint")
        b = buf[i]
        i += 1
        n |= (b & 0x7F) << shift
        shift += 7
        if not b & 0x80:
            return n, i


def decode(buf: bytes) -> list[tuple[int, bytes | int]]:
    """Fields of one message level, without a schema: length-delimited values
    stay bytes (decode them again for nested messages)."""
    out: list[tuple[int, bytes | int]] = []
    i = 0
    while i < len(buf):
        key, i = _read_varint(buf, i)
        number, wire = key >> 3, key & 7
        if wire == 0:
            value, i = _read_varint(buf, i)
        elif wire == 2:
            length, i = _read_varint(buf, i)
            value = bytes(buf[i : i + length])
            if len(value) != length:
                raise ProtocolError("truncated field")
            i += length
        elif wire == 1:
            value, i = bytes(buf[i : i + 8]), i + 8
        elif wire == 5:
            value, i = bytes(buf[i : i + 4]), i + 4
        else:
            raise ProtocolError(f"wire type {wire}")
        out.append((number, value))
    return out


def _first(fields: list[tuple[int, bytes | int]], number: int) -> bytes | int | None:
    return next((v for n, v in fields if n == number), None)


def _text(value: bytes | int | None) -> str:
    return value.decode(errors="replace") if isinstance(value, bytes) else ""


# --- messages ----------------------------------------------------------------


def directive(namespace: str, name: str, payload: list[Field] | None = None) -> bytes:
    return encode((1, [(1, [(1, namespace), (2, name)]), (2, payload)]))


def discover() -> bytes:
    return directive("Alexa.Discovery", "Discover")


def iso(moment: datetime) -> str:
    """The clock's time format: local time with offset, whole seconds."""
    if moment.tzinfo is None:
        raise ValueError("naive datetime")
    return moment.isoformat(timespec="seconds")


def state_update(name: str, value: str) -> bytes:
    return directive("Alexa.Gadget.StateListener", "StateUpdate", [(1, [(1, name), (2, value)])])


def time_info(now: datetime) -> bytes:
    return state_update("timeinfo", iso(now))


def set_alert(token: str, kind: str, at: datetime) -> bytes:
    if kind not in ALERT_TYPES:
        raise ValueError(f"alert type {kind!r}")
    return directive("Alerts", "SetAlert", [(1, token), (2, kind), (3, iso(at))])


def delete_alert(token: str) -> bytes:
    return directive("Alerts", "DeleteAlert", [(1, token)])


def set_indicator(persist: bool = True, audio: bool = False) -> bytes:
    return directive("Notifications", "SetIndicator", [(1, persist), (2, audio)])


def clear_indicator() -> bytes:
    return directive("Notifications", "ClearIndicator")


def header(message: bytes) -> tuple[str, str]:
    """(namespace, name) of a directive or event."""
    try:
        body = _first(decode(message), 1)
        head = _first(decode(body), 1) if isinstance(body, bytes) else None
        fields = decode(head) if isinstance(head, bytes) else []
    except ProtocolError:
        return "", ""
    return _text(_first(fields, 1)), _text(_first(fields, 2))


@dataclass
class GadgetInfo:
    """What a clock says about itself in its Discover.Response."""

    serial: str = ""
    name: str = ""
    description: str = ""
    firmware: str = ""
    device_type: str = ""
    model: str = ""
    interfaces: dict[str, str] = field(default_factory=dict)

    def as_dict(self) -> dict:
        return {
            "serial": self.serial,
            "name": self.name,
            "description": self.description,
            "firmware": self.firmware,
            "device_type": self.device_type,
            "model": self.model,
            "interfaces": dict(self.interfaces),
        }

    @classmethod
    def from_dict(cls, data: dict) -> GadgetInfo:
        return cls(**{k: v for k, v in data.items() if k in cls.__dataclass_fields__})


def parse_discover_response(message: bytes) -> GadgetInfo:
    """Read a Discover.Response event (endpoints[0] only)."""
    if header(message) != ("Alexa.Discovery", "Discover.Response"):
        raise ProtocolError("not a Discover.Response")
    event = decode(_first(decode(message), 1))
    payload = decode(_first(event, 2) or b"")
    endpoint = decode(_first(payload, 1) or b"")
    info = GadgetInfo(
        serial=_text(_first(endpoint, 1)),
        name=_text(_first(endpoint, 2)),
        description=_text(_first(endpoint, 3)),
    )
    for number, value in endpoint:
        if number == 11 and isinstance(value, bytes):
            capability = decode(value)
            info.interfaces[_text(_first(capability, 2))] = _text(_first(capability, 3))
    extra = _first(endpoint, 12)
    if isinstance(extra, bytes):
        fields = decode(extra)
        info.firmware = _text(_first(fields, 1))
        info.device_type = _text(_first(fields, 4))
        info.model = _text(_first(fields, 5))
    return info


# --- framing -----------------------------------------------------------------


def _escape(data: bytes) -> bytes:
    out = bytearray()
    for b in data:
        if b in _SPECIAL:
            out += bytes((ESC, ESC ^ b))
        else:
            out.append(b)
    return bytes(out)


class Framer:
    """Frames outgoing messages and splits the incoming byte stream."""

    def __init__(self) -> None:
        self._seq = -1
        self._buf = bytearray()
        self._escaped = False
        self._inside = False

    def frame(self, payload: bytes) -> bytes:
        self._seq = (self._seq + 1) & 0xFF
        while self._seq in _SPECIAL:
            self._seq = (self._seq + 1) & 0xFF
        checksum = (PACKET_ID + sum(payload)) & 0xFFFF
        return (
            bytes((SOF, PACKET_ID, 0x00, self._seq))
            + _escape(payload)
            + _escape(checksum.to_bytes(2, "big"))
            + bytes((EOF,))
        )

    def feed(self, data: bytes) -> Iterator[bytes]:
        """Payloads of the frames completed by `data`; bad frames are skipped."""
        for b in data:
            if b == SOF:
                self._buf, self._escaped, self._inside = bytearray(), False, True
            elif not self._inside:
                continue
            elif b == EOF:
                self._inside = False
                frame = bytes(self._buf)
                if len(frame) < 5:
                    continue
                payload = frame[3:-2]
                checksum = int.from_bytes(frame[-2:], "big")
                if (frame[0] + frame[1] + sum(payload)) & 0xFFFF == checksum:
                    yield payload
            elif b == ESC:
                self._escaped = True
            else:
                self._buf.append(b ^ ESC if self._escaped else b)
                self._escaped = False
