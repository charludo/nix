"""Keeping clocks connected and happy, inside Home Assistant.

`Shared` is one system bus connection and one SPP record for all clocks;
`ClockRuntime` is one clock: its stored state, the background task that serves
its sessions, and the timers that announce (and end) due alerts.
"""

from __future__ import annotations

import asyncio
import contextlib
import logging
from collections.abc import Callable
from datetime import datetime, timedelta

from homeassistant.config_entries import ConfigEntry
from homeassistant.core import CALLBACK_TYPE, HomeAssistant, callback
from homeassistant.helpers import device_registry as dr
from homeassistant.helpers.event import async_call_later, async_track_point_in_time
from homeassistant.helpers.storage import Store
from homeassistant.util import dt as dt_util

from .bluez import Bluez, BluezError, open_link
from .clock import Alert, ClockState, WallClock
from .const import (
    CONF_ADAPTER,
    CONF_ADDRESS,
    CONF_RING_FOR,
    DEFAULT_RING_FOR,
    DOMAIN,
    EVENT_ALERT_DUE,
    EVENT_ALERT_ENDED,
    POLL_INTERVAL,
    STORAGE_VERSION,
)

_LOGGER = logging.getLogger(__name__)

PROFILE_RETRY = 10.0


class Shared:
    """The D-Bus connection and SPP record, shared by every configured clock."""

    def __init__(self, hass: HomeAssistant) -> None:
        self.hass = hass
        self.bluez = Bluez()
        self.users = 0
        self._retry: CALLBACK_TYPE | None = None

    @classmethod
    async def acquire(cls, hass: HomeAssistant) -> Shared:
        shared: Shared | None = hass.data.get(DOMAIN)
        if shared is None:
            shared = cls(hass)
            await shared.bluez.connect()
            hass.data[DOMAIN] = shared
        shared.users += 1
        if shared.users == 1:
            await shared._register()
        return shared

    async def release(self) -> None:
        self.users -= 1
        if self.users > 0:
            return
        if self._retry:
            self._retry()
            self._retry = None
        await self.bluez.unregister_profile()
        self.bluez.close()
        self.hass.data.pop(DOMAIN, None)

    async def _register(self) -> None:
        try:
            await self.bluez.register_profile(self._lost)
        except BluezError as err:
            _LOGGER.warning("Couldn't publish the Serial Port record, retrying: %s", err)
            self._lost()

    @callback
    def _lost(self) -> None:
        """BlueZ dropped the record (or refused it): try again shortly."""
        if self.users <= 0 or self._retry:
            return

        @callback
        def again(_now: datetime) -> None:
            self._retry = None
            self.hass.async_create_task(self._register(), eager_start=True)

        self._retry = async_call_later(self.hass, PROFILE_RETRY, again)


class ClockRuntime:
    """One configured clock."""

    def __init__(self, hass: HomeAssistant, entry: ConfigEntry, shared: Shared) -> None:
        self.hass = hass
        self.entry = entry
        self.shared = shared
        self.address: str = entry.data[CONF_ADDRESS]
        self.adapter: str = entry.data[CONF_ADAPTER]
        self._store: Store[dict] = Store(
            hass, STORAGE_VERSION, f"{DOMAIN}.{entry.entry_id}", private=True
        )
        self.clock = WallClock(ClockState(), dt_util.now, self._changed)
        self._listeners: list[Callable[[], None]] = []
        self._wake = asyncio.Event()
        self._unsubs: list[CALLBACK_TYPE] = []
        self._due: dict[str, CALLBACK_TYPE] = {}
        self._announced: dict[str, datetime] = {}
        self._local_address: str | None = None
        self._known_info = None
        # Set by the integration's setup once the device is registered.
        self.device_id: str | None = None

    @property
    def ring_for(self) -> timedelta:
        return timedelta(seconds=self.entry.options.get(CONF_RING_FOR, DEFAULT_RING_FOR))

    @property
    def connected(self) -> bool:
        return self.clock.connected

    def ringing(self, alert: Alert) -> bool:
        return alert.at <= dt_util.now()

    # --- lifecycle ------------------------------------------------------------

    async def async_start(self) -> None:
        self.clock.state = ClockState.from_dict(await self._store.async_load())
        self._known_info = self.clock.state.info
        # Alerts that ran out while Home Assistant was down.
        for alert in self.clock.expire(self.ring_for):
            self._fire(EVENT_ALERT_ENDED, alert, "expired")
        with contextlib.suppress(BluezError, KeyError):
            adapters = {a.path: a for a in await self.shared.bluez.adapters()}
            self._local_address = adapters[self.adapter].address
        self._unsubs.append(
            self.shared.bluez.watch_connected(self.adapter, self.address, self._link_changed)
        )
        self._schedule()
        self.entry.async_create_background_task(
            self.hass, self._serve(), f"{DOMAIN} {self.address}", eager_start=True
        )

    async def async_stop(self) -> None:
        for unsub in self._unsubs:
            unsub()
        for unsub in self._due.values():
            unsub()
        self._due.clear()
        await self._store.async_save(self.clock.state.as_dict())

    @callback
    def _link_changed(self, up: bool) -> None:
        if up:
            self._wake.set()

    async def _serve(self) -> None:
        """Forever: when the clock links up, connect back and stay."""
        while True:
            with contextlib.suppress(TimeoutError):
                await asyncio.wait_for(self._wake.wait(), POLL_INTERVAL.total_seconds())
            self._wake.clear()
            if not await self.shared.bluez.is_connected(self.adapter, self.address):
                continue
            try:
                await self.clock.run_session(
                    lambda: open_link(self.address, local=self._local_address)
                )
            except OSError as err:
                _LOGGER.debug("Session with %s ended: %s", self.address, err)
            # Let the clock finish its own disconnect before looking again.
            await asyncio.sleep(1)

    # --- changes ------------------------------------------------------------

    @callback
    def async_add_listener(self, listener: Callable[[], None]) -> CALLBACK_TYPE:
        self._listeners.append(listener)
        return lambda: self._listeners.remove(listener)

    @callback
    def _changed(self) -> None:
        self._store.async_delay_save(self.clock.state.as_dict, 1)
        self._schedule()
        info = self.clock.state.info
        if info and info != self._known_info:
            self._known_info = info
            self._update_device(info)
        for listener in list(self._listeners):
            listener()

    def _update_device(self, info) -> None:
        if self.device_id:
            dr.async_get(self.hass).async_update_device(
                self.device_id,
                serial_number=info.serial or None,
                sw_version=info.firmware or None,
            )

    # --- due and ended alerts -------------------------------------------------

    @callback
    def _schedule(self) -> None:
        """One timer per alert: when it's due, then when it should stop ringing."""
        alerts = self.clock.state.alerts
        for token in list(self._due):
            if token not in alerts:
                self._due.pop(token)()
        for token in list(self._announced):
            if token not in alerts or alerts[token].at != self._announced[token]:
                self._announced.pop(token)
        for token, alert in alerts.items():
            if token in self._due:
                self._due.pop(token)()
            if token in self._announced:
                when = alert.at + self.ring_for
                action = self._ring_over
            else:
                when = alert.at
                action = self._now_due
            self._due[token] = async_track_point_in_time(
                self.hass, self._make_job(token, action), when
            )

    def _make_job(self, token: str, action):
        @callback
        def job(_now: datetime) -> None:
            self._due.pop(token, None)
            alert = self.clock.state.alerts.get(token)
            if alert is not None:
                action(alert)

        return job

    @callback
    def _now_due(self, alert: Alert) -> None:
        self._announced[alert.token] = alert.at
        self._fire(EVENT_ALERT_DUE, alert)
        self._schedule()
        for listener in list(self._listeners):
            listener()

    @callback
    def _ring_over(self, alert: Alert) -> None:
        self.hass.async_create_task(self.async_cancel(alert.token, "timeout"), eager_start=True)

    def _fire(self, event: str, alert: Alert, reason: str | None = None) -> None:
        data = {**alert.as_dict(), "address": self.address}
        if self.device_id:
            data["device_id"] = self.device_id
        if reason:
            data["reason"] = reason
        self.hass.bus.async_fire(event, data)

    async def async_cancel(self, token: str, reason: str = "cancelled") -> bool:
        alert = self.clock.state.alerts.get(token)
        if alert is None:
            return False
        was_due = token in self._announced
        await self.clock.cancel_alert(token)
        if was_due:
            self._fire(EVENT_ALERT_ENDED, alert, reason)
        return True
