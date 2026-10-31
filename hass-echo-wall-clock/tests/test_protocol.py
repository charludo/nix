"""The wire format, checked against what a real Echo sent a real clock."""

from datetime import datetime, timedelta, timezone

import pytest
from fakeclock import discover_response

from echo_wall_clock import protocol

CET = timezone(timedelta(hours=1))

# Recorded from an Echo (Alexa.Gadget.StateListener/StateUpdate, timeinfo).
ECHO_TIMEINFO = bytes.fromhex(
    "0a540a290a1a416c6578612e4761646765742e53746174654c697374656e6572"
    "120b5374617465557064617465"
    "12270a250a0874696d65696e666f"
    "1219323032362d31302d33315431363a32363a35382b30313a3030"
)
# Alerts/SetAlert, a reminder.
ECHO_SET_ALERT = bytes.fromhex(
    "0a470a120a06416c657274731208536574416c657274"
    "12310a0a33383638343935313135120852454d494e444552"
    "1a19323032362d31312d30315431373a30303a30302b30313a3030"
)
# Alexa.Discovery/Discover.
ECHO_DISCOVER = bytes.fromhex("0a1d0a1b0a0f416c6578612e446973636f766572791208446973636f766572")
# Notifications/ClearIndicator, as the whole frame (sequence number 4).
ECHO_CLEAR_INDICATOR_FRAME = bytes.fromhex(
    "f00200040a210a1f0a0d4e6f74696669636174696f6e73120e436c656172496e64696361746f720b6bf1"
)


def test_messages_are_byte_identical_to_an_echo():
    assert protocol.discover() == ECHO_DISCOVER
    assert protocol.time_info(datetime(2026, 10, 31, 16, 26, 58, tzinfo=CET)) == ECHO_TIMEINFO
    at = datetime(2026, 11, 1, 17, 0, tzinfo=CET)
    assert protocol.set_alert("3868495115", "REMINDER", at) == ECHO_SET_ALERT
    framer = protocol.Framer()
    framer._seq = 3
    assert framer.frame(protocol.clear_indicator()) == ECHO_CLEAR_INDICATOR_FRAME


def test_header_has_namespace_and_name_only():
    """The clock drops directives with a messageId it can't fit."""
    message = protocol.set_alert("1", "TIMER", datetime(2026, 1, 1, tzinfo=CET))
    head = protocol.decode(dict(protocol.decode(protocol.decode(message)[0][1]))[1])
    assert [n for n, _ in head] == [1, 2]


def test_frames_round_trip_with_escapes():
    tx, rx = protocol.Framer(), protocol.Framer()
    payloads = [bytes([0xF0, 0xF1, 0xF2, 0x00]), b"plain", bytes(range(256))]
    stream = b"".join(tx.frame(p) for p in payloads)
    # Split anywhere: the stream arrives in pieces.
    got = list(rx.feed(stream[:7])) + list(rx.feed(stream[7:300])) + list(rx.feed(stream[300:]))
    assert got == payloads


def test_sequence_skips_special_bytes():
    framer = protocol.Framer()
    seqs = [framer.frame(b"x")[3] for _ in range(260)]
    assert not {0xF0, 0xF1, 0xF2} & set(seqs)


def test_bad_checksum_is_dropped():
    frame = bytearray(protocol.Framer().frame(b"hello"))
    frame[5] ^= 1
    assert list(protocol.Framer().feed(bytes(frame))) == []


def test_discover_response():
    info = protocol.parse_discover_response(discover_response(serial="G0SERIAL"))
    assert info.serial == "G0SERIAL"
    assert info.firmware == "102"
    assert info.model == "AlexaGadgetsEWC"
    assert info.interfaces == {
        "Alexa.Gadget.StateListener": "1.0",
        "Alerts": "1.1",
        "Notifications": "1.0",
    }
    assert protocol.GadgetInfo.from_dict(info.as_dict()) == info


def test_rejects_naive_times_and_unknown_kinds():
    with pytest.raises(ValueError):
        protocol.time_info(datetime(2026, 1, 1))
    with pytest.raises(ValueError):
        protocol.set_alert("1", "SNOOZE", datetime(2026, 1, 1, tzinfo=CET))
