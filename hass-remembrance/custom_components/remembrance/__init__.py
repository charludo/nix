"""Remembrance: central timers, reminders and alarms for Home Assistant.

An engine with services, entities and events; how it's used (voice, UI,
automations) is up to the caller.
"""

from __future__ import annotations

import inspect
from datetime import date, datetime, time
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
    CONF_ALARM_CATEGORY,
    CONF_CALENDAR,
    CONF_DEFAULT_AREA,
    CONF_INTERVAL,
    CONF_LIMIT,
    CONF_MISSED_GRACE,
    CONF_PASSWORD,
    CONF_POLL_INTERVAL,
    CONF_REMINDER_CATEGORY,
    CONF_RING,
    CONF_RING_SCRIPT,
    CONF_SNOOZE_DELAY,
    CONF_URL,
    CONF_USERNAME,
    DOMAIN,
    KIND_ALARM,
    KIND_REMINDER,
    KINDS,
    STATUS_INVALID,
    STATUS_OK,
)
from .engine import Engine, Result, Target
from .timers import Selector


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


def _blank_or(validator):
    """Empty means not given: templates (e.g. in intent scripts) can't leave
    a field out conditionally."""

    def validate(value: Any) -> Any:
        if value is None or (isinstance(value, str) and not value.strip()):
            return None
        return validator(value)

    return validate


RING_SCHEMA = vol.Schema(
    {
        vol.Optional(CONF_INTERVAL): vol.All(_seconds, vol.Range(min=1)),
        vol.Optional(CONF_LIMIT): vol.All(_seconds, vol.Range(min=0)),
    }
)

CALENDAR_SCHEMA = vol.Schema(
    {
        # The calendar's own URL.
        vol.Required(CONF_URL): cv.url,
        vol.Optional(CONF_USERNAME): cv.string,
        vol.Optional(CONF_PASSWORD): cv.string,
        vol.Optional(CONF_POLL_INTERVAL): vol.All(_seconds, vol.Range(min=10)),
        vol.Optional(CONF_REMINDER_CATEGORY): cv.string,
        vol.Optional(CONF_ALARM_CATEGORY): cv.string,
    }
)

CONFIG_SCHEMA = vol.Schema(
    {
        DOMAIN: vol.Schema(
            {
                vol.Optional(CONF_RING_SCRIPT): cv.entity_id,
                vol.Optional(CONF_RING, default={}): {vol.In(KINDS): RING_SCHEMA},
                vol.Optional(CONF_SNOOZE_DELAY): _seconds,
                vol.Optional(CONF_MISSED_GRACE): _seconds,
                vol.Optional(CONF_DEFAULT_AREA): cv.string,
                vol.Optional(CONF_CALENDAR): CALENDAR_SCHEMA,
            }
        )
    },
    extra=vol.ALLOW_EXTRA,
)

# Fields every service acting on existing items accepts (see the ToDo's API).
TARGET_FIELDS = {
    vol.Optional("id"): vol.All(cv.ensure_list, [cv.string]),
    vol.Optional("entity_id"): cv.entity_ids,
    vol.Optional("label"): _blank_or(cv.string),
    vol.Optional("duration"): _blank_or(_seconds),
    vol.Optional("remaining"): _blank_or(_seconds),
    vol.Optional("time"): _blank_or(cv.time),
    vol.Optional("area"): _blank_or(cv.string),
    vol.Optional("all", default=False): cv.boolean,
}

SERVICES: dict[str, vol.Schema] = {
    "timer_start": vol.Schema(
        {
            vol.Required("duration"): _seconds,
            vol.Optional("label"): _blank_or(cv.string),
            vol.Optional("area"): _blank_or(cv.string),
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
    "reminder_create": vol.Schema(
        {
            vol.Required("summary"): cv.string,
            vol.Optional("at"): _blank_or(cv.datetime),
            vol.Optional("in"): _blank_or(_seconds),
            vol.Optional("alerts"): vol.All(cv.ensure_list, [_seconds]),
            vol.Optional("area"): _blank_or(cv.string),
            vol.Optional("description"): _blank_or(cv.string),
        }
    ),
    "reminder_delete": vol.Schema(TARGET_FIELDS),
    "alarm_create": vol.Schema(
        {
            vol.Required("time"): cv.time,
            vol.Optional("days"): vol.All(cv.ensure_list, [cv.string]),
            vol.Optional("date"): _blank_or(cv.date),
            vol.Optional("label"): _blank_or(cv.string),
            vol.Optional("area"): _blank_or(cv.string),
            vol.Optional("description"): _blank_or(cv.string),
        }
    ),
    "alarm_skip": vol.Schema({**TARGET_FIELDS, vol.Optional("date"): _blank_or(cv.date)}),
    "alarm_enable": vol.Schema(TARGET_FIELDS),
    "alarm_disable": vol.Schema(TARGET_FIELDS),
    "alarm_delete": vol.Schema(TARGET_FIELDS),
    "dismiss": vol.Schema(TARGET_FIELDS),
    "snooze": vol.Schema({**TARGET_FIELDS, vol.Optional("delay"): _blank_or(_seconds)}),
    "query": vol.Schema(
        {
            **TARGET_FIELDS,
            vol.Optional("kind"): _blank_or(vol.In(KINDS)),
            vol.Optional("state"): _blank_or(
                vol.In(["running", "paused", "ringing", "scheduled", "disabled"])
            ),
            vol.Optional("from"): _blank_or(cv.datetime),
            vol.Optional("to"): _blank_or(cv.datetime),
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
            if entry and entry.platform == DOMAIN and "_" in entry.unique_id:
                ids.append(entry.unique_id.split("_", 1)[1])
            else:
                ids.append(f"unknown:{entity_id}")
        return Target(
            ids=ids,
            selector=Selector(
                label=data.get("label"),
                duration=data.get("duration") or None,
                remaining=data.get("remaining") or None,
                area=data.get("area"),
            ),
            all=data.get("all", False),
            at_time=data.get("time"),
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
            case "reminder_create":
                at: datetime | None = d.get("at")
                if at is None and not d.get("in"):
                    result = Result(STATUS_INVALID, reason="`at` or `in` needed")
                else:
                    result = engine.reminder_create(
                        d["summary"],
                        at,
                        d.get("in"),
                        d.get("alerts"),
                        d.get("area"),
                        d.get("description"),
                    )
            case "reminder_delete":
                result = engine.entry_delete(target_of(call), KIND_REMINDER)
            case "alarm_create":
                when: time = d["time"]
                on: date | None = d.get("date")
                result = engine.alarm_create(
                    when, d.get("days"), on, d.get("label"), d.get("area"), d.get("description")
                )
            case "alarm_skip":
                result = engine.alarm_skip(target_of(call), d.get("date"))
            case "alarm_enable":
                result = engine.alarm_set_enabled(target_of(call), True)
            case "alarm_disable":
                result = engine.alarm_set_enabled(target_of(call), False)
            case "alarm_delete":
                result = engine.entry_delete(target_of(call), KIND_ALARM)
            case "dismiss":
                result = engine.dismiss(target_of(call))
            case "snooze":
                result = engine.snooze(target_of(call), d.get("delay"))
            case "query":
                result = engine.query(
                    target_of(call), d.get("kind"), d.get("state"), d.get("from"), d.get("to")
                )
        if inspect.isawaitable(result):
            result = await result
        return respond(call, result)

    for name, schema in SERVICES.items():
        hass.services.async_register(
            DOMAIN, name, handle, schema=schema, supports_response=SupportsResponse.OPTIONAL
        )

    platforms = [Platform.SENSOR, Platform.BINARY_SENSOR]
    if engine.calendar:
        platforms += [Platform.CALENDAR, Platform.SWITCH]
    for platform in platforms:
        hass.async_create_task(async_load_platform(hass, platform, DOMAIN, {}, config))

    # The first sync needs the network; it mustn't hold up the setup.
    hass.async_create_background_task(engine.async_start(), f"{DOMAIN} start")

    async def unload(_event) -> None:
        await engine.async_unload()

    hass.bus.async_listen_once("homeassistant_stop", unload)
    return True
