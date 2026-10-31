"""One clock: what it should show, and the sessions that make it show it.

The clock comes to us: about once a minute while it misses its Echo, it opens a
Bluetooth link and waits a few seconds for the Echo to connect back. Whoever
notices that (the BlueZ layer) calls `run_session` with a way to open the data
channel; the session discovers the clock, sets its time, replays every alert,
and then stays connected, re-sending the time every half hour, until the link
drops.

Alerts are kept here, not just sent: the clock forgets nothing while it's
connected, but a new session (after a battery change, or Home Assistant
restarting) must bring it back up to date. Cancelling an alert while the clock
is away is remembered until it's back.

No Home Assistant imports here.
"""

from __future__ import annotations

import asyncio
import contextlib
import logging
import secrets
from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Protocol

from . import protocol
from .protocol import ALERT_TYPES, Framer, GadgetInfo

_LOGGER = logging.getLogger(__name__)

TIME_SYNC_EVERY = timedelta(minutes=30)
DISCOVER_TIMEOUT = 5.0
# A gap after Discover before the rest, as an Echo leaves one.
SETTLE = 0.2


class Link(Protocol):
    """A connected data channel to the clock."""

    async def send(self, data: bytes) -> None: ...

    async def recv(self) -> bytes:
        """Some bytes; b"" when the link is closed."""
        ...

    def close(self) -> None: ...


Opener = Callable[[], Awaitable[Link]]


@dataclass
class Alert:
    token: str
    kind: str
    at: datetime
    label: str | None = None

    def as_dict(self) -> dict:
        return {
            "alert_id": self.token,
            "kind": self.kind.lower(),
            "at": self.at.isoformat(),
            "label": self.label,
        }

    @classmethod
    def from_dict(cls, data: dict) -> Alert:
        return cls(
            token=data["alert_id"],
            kind=data["kind"].upper(),
            at=datetime.fromisoformat(data["at"]),
            label=data.get("label"),
        )


@dataclass
class ClockState:
    """Everything that survives a restart."""

    alerts: dict[str, Alert] = field(default_factory=dict)
    # Cancelled while the clock was away; deleted on its next session.
    pending_deletes: set[str] = field(default_factory=set)
    indicator: bool = False
    info: GadgetInfo | None = None

    def as_dict(self) -> dict:
        return {
            "alerts": [a.as_dict() for a in self.alerts.values()],
            "pending_deletes": sorted(self.pending_deletes),
            "indicator": self.indicator,
            "info": self.info.as_dict() if self.info else None,
        }

    @classmethod
    def from_dict(cls, data: dict | None) -> ClockState:
        if not data:
            return cls()
        alerts = [Alert.from_dict(a) for a in data.get("alerts", [])]
        info = data.get("info")
        return cls(
            alerts={a.token: a for a in alerts},
            pending_deletes=set(data.get("pending_deletes", [])),
            indicator=bool(data.get("indicator", False)),
            info=GadgetInfo.from_dict(info) if info else None,
        )


def new_token() -> str:
    # Short and numeric, like the Echo's; the clock keeps at most 63 chars.
    return str(secrets.randbelow(10**10)).zfill(10)


class WallClock:
    def __init__(
        self,
        state: ClockState,
        now: Callable[[], datetime],
        on_change: Callable[[], None] = lambda: None,
        time_sync_every: timedelta = TIME_SYNC_EVERY,
    ) -> None:
        self.state = state
        self._now = now
        self._on_change = on_change
        self._time_sync_every = time_sync_every
        self._link: Link | None = None
        self._framer = Framer()
        self._send_lock = asyncio.Lock()

    @property
    def connected(self) -> bool:
        return self._link is not None

    # --- what callers do ---------------------------------------------------

    async def set_alert(
        self, kind: str, at: datetime, token: str | None = None, label: str | None = None
    ) -> Alert:
        """Add an alert, or move/replace the one with this token."""
        kind = kind.upper()
        if kind not in ALERT_TYPES:
            raise ValueError(f"alert type {kind!r}")
        if at.tzinfo is None:
            raise ValueError("naive datetime")
        token = token or new_token()
        previous = self.state.alerts.get(token)
        alert = Alert(
            token, kind, at, label if label is not None else (previous and previous.label)
        )
        self.state.alerts[token] = alert
        self.state.pending_deletes.discard(token)
        if previous and previous.kind != kind:
            await self._send(protocol.delete_alert(token))
        await self._send(protocol.set_alert(token, kind, at))
        self._changed()
        return alert

    async def move_alert(self, token: str, at: datetime) -> Alert:
        alert = self.state.alerts.get(token)
        if alert is None:
            raise KeyError(token)
        return await self.set_alert(alert.kind, at, token)

    async def cancel_alert(self, token: str) -> bool:
        """Remove an alert; a ringing one stops ringing. False if unknown."""
        if self.state.alerts.pop(token, None) is None:
            return False
        if not await self._send(protocol.delete_alert(token)):
            self.state.pending_deletes.add(token)
        self._changed()
        return True

    async def cancel_all(self, kind: str | None = None) -> list[str]:
        tokens = [t for t, a in self.state.alerts.items() if kind is None or a.kind == kind.upper()]
        for token in tokens:
            await self.cancel_alert(token)
        return tokens

    async def set_indicator(self, on: bool) -> None:
        self.state.indicator = on
        await self._send(protocol.set_indicator() if on else protocol.clear_indicator())
        self._changed()

    async def sync_time(self) -> bool:
        return await self._send(protocol.time_info(self._now()))

    def expire(self, older_than: timedelta) -> list[Alert]:
        """Forget alerts whose time is more than `older_than` past, without
        telling the clock (it stops on its own by then)."""
        cutoff = self._now() - older_than
        gone = [a for a in self.state.alerts.values() if a.at < cutoff]
        for alert in gone:
            del self.state.alerts[alert.token]
        if gone:
            self._changed()
        return gone

    # --- sessions ----------------------------------------------------------

    async def run_session(self, open_link: Opener) -> None:
        """Connect, bring the clock up to date, and stay until the link drops."""
        link = await open_link()
        self._framer = Framer()
        rx = Framer()
        inbox: asyncio.Queue[bytes] = asyncio.Queue()

        async def reader() -> None:
            while data := await link.recv():
                for message in rx.feed(data):
                    inbox.put_nowait(message)

        reading = asyncio.create_task(reader())
        self._link = link
        try:
            await self._send(protocol.discover())
            await self._await_discovery(inbox, reading)
            await asyncio.sleep(SETTLE)
            await self._replay()
            self._changed()
            await self._stay(inbox, reading)
        finally:
            self._link = None
            reading.cancel()
            with contextlib.suppress(asyncio.CancelledError, OSError):
                await reading
            link.close()
            self._changed()

    async def _await_discovery(self, inbox: asyncio.Queue[bytes], reading: asyncio.Task) -> None:
        deadline = asyncio.get_running_loop().time() + DISCOVER_TIMEOUT
        while (left := deadline - asyncio.get_running_loop().time()) > 0:
            message = await self._next(inbox, reading, left)
            if message is None:
                break
            if protocol.header(message) == ("Alexa.Discovery", "Discover.Response"):
                try:
                    self.state.info = protocol.parse_discover_response(message)
                except protocol.ProtocolError as err:
                    _LOGGER.debug("Unreadable Discover.Response: %s", err)
                return
        _LOGGER.debug("No Discover.Response; carrying on")

    async def _replay(self) -> None:
        await self.sync_time()
        for token in sorted(self.state.pending_deletes):
            await self._send(protocol.delete_alert(token))
        self.state.pending_deletes.clear()
        for alert in sorted(self.state.alerts.values(), key=lambda a: a.at):
            await self._send(protocol.set_alert(alert.token, alert.kind, alert.at))
        await self._send(
            protocol.set_indicator() if self.state.indicator else protocol.clear_indicator()
        )

    async def _stay(self, inbox: asyncio.Queue[bytes], reading: asyncio.Task) -> None:
        period = self._time_sync_every.total_seconds()
        while True:
            message = await self._next(inbox, reading, period)
            if message is None:
                if reading.done():
                    return
                await self.sync_time()
                continue
            _LOGGER.debug("From the clock: %s", protocol.header(message))

    @staticmethod
    async def _next(
        inbox: asyncio.Queue[bytes], reading: asyncio.Task, timeout: float
    ) -> bytes | None:
        """The next message; None on timeout or when the link has closed."""
        getting = asyncio.ensure_future(inbox.get())
        done, _ = await asyncio.wait(
            {getting, reading}, timeout=timeout, return_when="FIRST_COMPLETED"
        )
        if getting in done:
            return getting.result()
        getting.cancel()
        return None

    async def _send(self, message: bytes) -> bool:
        link = self._link
        if link is None:
            return False
        try:
            async with self._send_lock:
                await link.send(self._framer.frame(message))
        except OSError as err:
            _LOGGER.debug("Send failed: %s", err)
            return False
        return True

    def _changed(self) -> None:
        try:
            self._on_change()
        except Exception:  # a listener's problem, not the session's
            _LOGGER.exception("Change listener failed")
