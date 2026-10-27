"""Remembrance: central timers, reminders and alarms for Home Assistant.

An engine with services, entities and events; how it's used (voice, UI,
automations) is up to the caller.
"""

from __future__ import annotations

from typing import Any

import voluptuous as vol
from homeassistant.const import Platform
from homeassistant.core import (
    HomeAssistant,
    ServiceCall,
    ServiceResponse,
    SupportsResponse,
)
from homeassistant.exceptions import ServiceValidationError
from homeassistant.helpers import config_validation as cv
from homeassistant.helpers import entity_registry as er
from homeassistant.helpers.discovery import async_load_platform
from homeassistant.helpers.typing import ConfigType

from .const import (
    CONF_DEFAULT_AREA,
    CONF_INTERVAL,
    CONF_LIMIT,
    CONF_MISSED_GRACE,
    CONF_RING,
    CONF_RING_SCRIPT,
    CONF_SNOOZE_DELAY,
    DOMAIN,
    KIND_TIMER,
    STATUS_OK,
)
from .engine import Engine, Result, Target
from .timers import Selector, TimerState

PLATFORMS = [Platform.SENSOR, Platform.BINARY_SENSOR]


def _seconds(value: Any) -> float:
    return cv.time_period(value).total_seconds()


def _signed_seconds(value: Any) -> float:
    """Like `_seconds`, but negative values (number or "-00:01:00") allowed."""
    if isinstance(value, int | float):
        return float(value)
    text = str(value).strip()
    if text.startswith("-"):
        return -_seconds(text[1:])
    return _seconds(text)


RING_SCHEMA = vol.Schema(
    {
        vol.Optional(CONF_INTERVAL): vol.All(_seconds, vol.Range(min=1)),
        vol.Optional(CONF_LIMIT): vol.All(_seconds, vol.Range(min=0)),
    }
)

CONFIG_SCHEMA = vol.Schema(
    {
        DOMAIN: vol.Schema(
            {
                vol.Optional(CONF_RING_SCRIPT): cv.entity_id,
                vol.Optional(CONF_RING, default={}): {vol.In([KIND_TIMER]): RING_SCHEMA},
                vol.Optional(CONF_SNOOZE_DELAY): _seconds,
                vol.Optional(CONF_MISSED_GRACE): _seconds,
                vol.Optional(CONF_DEFAULT_AREA): cv.string,
            }
        )
    },
    extra=vol.ALLOW_EXTRA,
)

# Fields every service acting on existing items accepts (see the ToDo's API).
TARGET_FIELDS = {
    vol.Optional("id"): vol.All(cv.ensure_list, [cv.string]),
    vol.Optional("entity_id"): cv.entity_ids,
    vol.Optional("label"): cv.string,
    vol.Optional("duration"): _seconds,
    vol.Optional("remaining"): _seconds,
    vol.Optional("area"): cv.string,
    vol.Optional("all", default=False): cv.boolean,
}

SERVICES: dict[str, vol.Schema] = {
    "timer_start": vol.Schema(
        {
            vol.Required("duration"): _seconds,
            vol.Optional("label"): cv.string,
            vol.Optional("area"): cv.string,
        }
    ),
    "timer_adjust": vol.All(
        vol.Schema(
            {
                **TARGET_FIELDS,
                vol.Exclusive("delta", "change"): _signed_seconds,
                vol.Exclusive("set_remaining", "change"): _seconds,
            }
        ),
        cv.has_at_least_one_key("delta", "set_remaining"),
    ),
    "timer_pause": vol.Schema(TARGET_FIELDS),
    "timer_resume": vol.Schema(TARGET_FIELDS),
    "timer_cancel": vol.Schema(TARGET_FIELDS),
    "dismiss": vol.Schema(TARGET_FIELDS),
    "snooze": vol.Schema({**TARGET_FIELDS, vol.Optional("delay"): _seconds}),
    "query": vol.Schema(
        {
            **TARGET_FIELDS,
            vol.Optional("kind"): vol.In([KIND_TIMER]),
            vol.Optional("state"): vol.In([str(s) for s in TimerState]),
        }
    ),
}


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    if DOMAIN not in config:
        return True
    engine = Engine(hass, config[DOMAIN])
    await engine.async_load()
    hass.data[DOMAIN] = engine

    def target_of(call: ServiceCall) -> Target:
        data = call.data
        ids = list(data.get("id", []))
        registry = er.async_get(hass)
        for entity_id in data.get("entity_id", []):
            entry = registry.async_get(entity_id)
            if entry and entry.platform == DOMAIN and entry.unique_id.startswith("timer_"):
                ids.append(entry.unique_id.removeprefix("timer_"))
            else:
                ids.append(f"unknown:{entity_id}")
        # Empty and zero mean "not given": templates (e.g. in intent scripts)
        # can't leave a field out conditionally.
        return Target(
            ids=ids,
            selector=Selector(
                label=data.get("label") or None,
                duration=data.get("duration") or None,
                remaining=data.get("remaining") or None,
                area=data.get("area") or None,
            ),
            all=data.get("all", False),
        )

    def respond(call: ServiceCall, result: Result) -> ServiceResponse:
        if result.status != STATUS_OK and not call.return_response:
            # Without a response nobody sees the status: make it an error.
            raise ServiceValidationError(
                f"{call.service}: {result.status}"
                + (f" ({result.reason})" if result.reason else "")
                + (
                    f", candidates: {[c['id'] for c in result.candidates]}"
                    if result.candidates
                    else ""
                )
            )
        return result.as_response() if call.return_response else None

    async def handle(call: ServiceCall) -> ServiceResponse:
        d = call.data
        match call.service:
            case "timer_start":
                result = engine.timer_start(d["duration"], d.get("label"), d.get("area"))
            case "timer_adjust":
                result = engine.timer_adjust(
                    target_of(call), d.get("delta"), d.get("set_remaining")
                )
            case "timer_pause":
                result = engine.timer_pause(target_of(call))
            case "timer_resume":
                result = engine.timer_resume(target_of(call))
            case "timer_cancel":
                result = engine.timer_cancel(target_of(call))
            case "dismiss":
                result = engine.dismiss(target_of(call))
            case "snooze":
                result = engine.snooze(target_of(call), d.get("delay"))
            case "query":
                result = engine.query(target_of(call), d.get("kind"), d.get("state"))
        return respond(call, result)

    for name, schema in SERVICES.items():
        hass.services.async_register(
            DOMAIN, name, handle, schema=schema, supports_response=SupportsResponse.OPTIONAL
        )

    for platform in PLATFORMS:
        hass.async_create_task(async_load_platform(hass, platform, DOMAIN, {}, config))

    async def unload(_event) -> None:
        await engine.async_unload()

    hass.bus.async_listen_once("homeassistant_stop", unload)
    return True
