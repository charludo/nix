"""Echo Wall Clock: the clock's timers, alarms and reminders, without an Echo.

Home Assistant takes the Echo's place: it keeps the clock connected over Classic
Bluetooth (BlueZ), sets its time, and puts alerts on its LED ring. What sets
those alerts (voice, automations, another integration) is up to the caller.
"""

from __future__ import annotations

from datetime import datetime, time, timedelta
from typing import Any

import voluptuous as vol
from homeassistant.config_entries import ConfigEntry, ConfigEntryState
from homeassistant.const import Platform
from homeassistant.core import (
    HomeAssistant,
    ServiceCall,
    ServiceResponse,
    SupportsResponse,
)
from homeassistant.exceptions import ConfigEntryNotReady, ServiceValidationError
from homeassistant.helpers import config_validation as cv
from homeassistant.helpers import device_registry as dr
from homeassistant.helpers.typing import ConfigType
from homeassistant.util import dt as dt_util

from .bluez import BluezError, sockets_supported
from .clock import Alert
from .const import (
    ATTR_ALERT_ID,
    ATTR_AT,
    ATTR_DEVICE_ID,
    ATTR_DURATION,
    ATTR_EXTEND,
    ATTR_KIND,
    ATTR_LABEL,
    DOMAIN,
    KIND_ALARM,
    KIND_REMINDER,
    KIND_TIMER,
    KINDS,
)
from .runtime import ClockRuntime, Shared

PLATFORMS = [Platform.BINARY_SENSOR, Platform.BUTTON, Platform.SENSOR, Platform.SWITCH]

CONFIG_SCHEMA = cv.config_entry_only_config_schema(DOMAIN)

type EchoWallClockConfigEntry = ConfigEntry[ClockRuntime]


async def async_setup_entry(hass: HomeAssistant, entry: EchoWallClockConfigEntry) -> bool:
    if not sockets_supported():
        raise ConfigEntryNotReady(translation_domain=DOMAIN, translation_key="no_bluetooth_sockets")
    try:
        shared = await Shared.acquire(hass)
    except BluezError as err:
        raise ConfigEntryNotReady(
            translation_domain=DOMAIN,
            translation_key="no_bluez",
            translation_placeholders={"error": str(err)},
        ) from err
    runtime = ClockRuntime(hass, entry, shared)
    entry.runtime_data = runtime
    runtime.device_id = (
        dr.async_get(hass)
        .async_get_or_create(
            config_entry_id=entry.entry_id,
            identifiers={(DOMAIN, runtime.address)},
            connections={(dr.CONNECTION_BLUETOOTH, runtime.address)},
            manufacturer="Amazon",
            model="Echo Wall Clock",
            name=entry.title,
        )
        .id
    )
    await runtime.async_start()
    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)
    entry.async_on_unload(entry.add_update_listener(_options_updated))
    return True


async def async_unload_entry(hass: HomeAssistant, entry: EchoWallClockConfigEntry) -> bool:
    if not await hass.config_entries.async_unload_platforms(entry, PLATFORMS):
        return False
    await entry.runtime_data.async_stop()
    await entry.runtime_data.shared.release()
    return True


async def _options_updated(hass: HomeAssistant, entry: EchoWallClockConfigEntry) -> None:
    entry.runtime_data._schedule()


# --- actions --------------------------------------------------------------------


def _local(value: Any) -> datetime:
    """A moment from a datetime or a time of day (the next one), in local time."""
    if isinstance(value, datetime):
        return (
            dt_util.as_local(value)
            if value.tzinfo
            else value.replace(tzinfo=dt_util.get_default_time_zone())
        )
    if isinstance(value, time):
        now = dt_util.now()
        moment = now.replace(
            hour=value.hour, minute=value.minute, second=value.second, microsecond=0
        )
        return moment if moment > now else moment + timedelta(days=1)
    raise vol.Invalid("expected a date and time, or a time of day")


def _signed_period(value: Any) -> timedelta:
    if isinstance(value, int | float):
        return timedelta(seconds=value)
    text = str(value).strip() if isinstance(value, str) else None
    if text and text.startswith("-"):
        return -cv.time_period(text[1:])
    return cv.time_period(value)


MOMENT = vol.All(vol.Any(cv.datetime, cv.time), _local)
POSITIVE_PERIOD = vol.All(cv.time_period, cv.positive_timedelta)

BASE = {vol.Optional(ATTR_DEVICE_ID): cv.string}
ALERT = {
    **BASE,
    vol.Optional(ATTR_ALERT_ID): vol.All(cv.string, vol.Length(min=1, max=255)),
    vol.Optional(ATTR_LABEL): cv.string,
}

SCHEMAS = {
    "set_timer": vol.Schema({**ALERT, vol.Required(ATTR_DURATION): POSITIVE_PERIOD}),
    "set_alarm": vol.Schema({**ALERT, vol.Required(ATTR_AT): MOMENT}),
    "set_reminder": vol.Schema({**ALERT, vol.Required(ATTR_AT): MOMENT}),
    "update_alert": vol.Schema(
        {
            **BASE,
            vol.Required(ATTR_ALERT_ID): cv.string,
            vol.Exclusive(ATTR_AT, "when"): MOMENT,
            vol.Exclusive(ATTR_DURATION, "when"): POSITIVE_PERIOD,
            vol.Exclusive(ATTR_EXTEND, "when"): _signed_period,
        }
    ),
    "cancel_alert": vol.Schema({**BASE, vol.Required(ATTR_ALERT_ID): cv.string}),
    "cancel_all": vol.Schema({**BASE, vol.Optional(ATTR_KIND): vol.In(KINDS)}),
    "list_alerts": vol.Schema({**BASE, vol.Optional(ATTR_KIND): vol.In(KINDS)}),
    "sync_time": vol.Schema(BASE),
}


def _runtime(hass: HomeAssistant, call: ServiceCall) -> ClockRuntime:
    loaded = [
        e for e in hass.config_entries.async_entries(DOMAIN) if e.state is ConfigEntryState.LOADED
    ]
    device_id = call.data.get(ATTR_DEVICE_ID)
    if device_id is None:
        if len(loaded) == 1:
            return loaded[0].runtime_data
        raise ServiceValidationError(
            translation_domain=DOMAIN,
            translation_key="which_clock" if loaded else "no_clock",
        )
    device = dr.async_get(hass).async_get(device_id)
    for entry in loaded:
        if device and entry.entry_id in device.config_entries:
            return entry.runtime_data
    raise ServiceValidationError(
        translation_domain=DOMAIN,
        translation_key="unknown_clock",
        translation_placeholders={"device_id": device_id},
    )


def _response(runtime: ClockRuntime, alert: Alert) -> dict:
    return {**alert.as_dict(), "ringing": runtime.ringing(alert)}


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    async def set_alert(call: ServiceCall, kind: str, at: datetime) -> ServiceResponse:
        runtime = _runtime(hass, call)
        if at <= dt_util.now():
            raise ServiceValidationError(translation_domain=DOMAIN, translation_key="in_the_past")
        alert = await runtime.clock.set_alert(
            kind, at, call.data.get(ATTR_ALERT_ID), call.data.get(ATTR_LABEL)
        )
        return _response(runtime, alert)

    async def set_timer(call: ServiceCall) -> ServiceResponse:
        return await set_alert(call, KIND_TIMER, dt_util.now() + call.data[ATTR_DURATION])

    async def set_alarm(call: ServiceCall) -> ServiceResponse:
        return await set_alert(call, KIND_ALARM, call.data[ATTR_AT])

    async def set_reminder(call: ServiceCall) -> ServiceResponse:
        return await set_alert(call, KIND_REMINDER, call.data[ATTR_AT])

    async def update_alert(call: ServiceCall) -> ServiceResponse:
        runtime = _runtime(hass, call)
        key = call.data[ATTR_ALERT_ID]
        alert = runtime.clock.state.alerts.get(key)
        if alert is None:
            raise ServiceValidationError(
                translation_domain=DOMAIN,
                translation_key="unknown_alert",
                translation_placeholders={"alert_id": key},
            )
        if ATTR_AT in call.data:
            at = call.data[ATTR_AT]
        elif ATTR_DURATION in call.data:
            at = dt_util.now() + call.data[ATTR_DURATION]
        elif ATTR_EXTEND in call.data:
            at = max(alert.at, dt_util.now()) + call.data[ATTR_EXTEND]
        else:
            raise ServiceValidationError(translation_domain=DOMAIN, translation_key="no_change")
        if at <= dt_util.now():
            # Moved into the past: that's the end of it.
            await runtime.async_cancel(key)
            return {**alert.as_dict(), "cancelled": True}
        return _response(runtime, await runtime.clock.move_alert(key, at))

    async def cancel_alert(call: ServiceCall) -> ServiceResponse:
        runtime = _runtime(hass, call)
        key = call.data[ATTR_ALERT_ID]
        alert = runtime.clock.state.alerts.get(key)
        if not await runtime.async_cancel(key):
            raise ServiceValidationError(
                translation_domain=DOMAIN,
                translation_key="unknown_alert",
                translation_placeholders={"alert_id": key},
            )
        return {**alert.as_dict(), "cancelled": True}

    async def cancel_all(call: ServiceCall) -> ServiceResponse:
        runtime = _runtime(hass, call)
        kind = call.data.get(ATTR_KIND)
        keys = [
            t
            for t, a in runtime.clock.state.alerts.items()
            if kind is None or a.kind == kind.upper()
        ]
        for key in keys:
            await runtime.async_cancel(key)
        return {"cancelled": keys}

    async def list_alerts(call: ServiceCall) -> ServiceResponse:
        runtime = _runtime(hass, call)
        kind = call.data.get(ATTR_KIND)
        alerts = sorted(runtime.clock.state.alerts.values(), key=lambda a: a.at)
        return {
            "connected": runtime.connected,
            "alerts": [
                _response(runtime, a) for a in alerts if kind is None or a.kind == kind.upper()
            ],
        }

    async def sync_time(call: ServiceCall) -> None:
        await _runtime(hass, call).clock.sync_time()

    handlers = {
        "set_timer": (set_timer, SupportsResponse.OPTIONAL),
        "set_alarm": (set_alarm, SupportsResponse.OPTIONAL),
        "set_reminder": (set_reminder, SupportsResponse.OPTIONAL),
        "update_alert": (update_alert, SupportsResponse.OPTIONAL),
        "cancel_alert": (cancel_alert, SupportsResponse.OPTIONAL),
        "cancel_all": (cancel_all, SupportsResponse.OPTIONAL),
        "list_alerts": (list_alerts, SupportsResponse.ONLY),
        "sync_time": (sync_time, SupportsResponse.NONE),
    }
    for name, (handler, response) in handlers.items():
        hass.services.async_register(
            DOMAIN, name, handler, schema=SCHEMAS[name], supports_response=response
        )
    return True
