"""One switch per repeating alarm: on while it's enabled. Mirrors the event's
status in the calendar (CANCELLED while off)."""

from __future__ import annotations

from typing import Any

from homeassistant.components.switch import SwitchEntity
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers import entity_registry as er
from homeassistant.helpers.dispatcher import async_dispatcher_connect
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from .const import DOMAIN, KIND_ALARM, SIGNAL_UPDATED
from .engine import Engine, Target


async def async_setup_platform(
    hass: HomeAssistant, config, async_add_entities: AddEntitiesCallback, discovery_info=None
) -> None:
    engine: Engine = hass.data[DOMAIN]
    assert engine.calendar
    switches: dict[str, AlarmSwitch] = {}

    @callback
    def sync(_changed_id: str | None = None) -> None:
        assert engine.calendar
        alarms = {
            uid: e
            for uid, e in engine.calendar.entries.items()
            if e.kind == KIND_ALARM and e.recurring
        }
        new = [AlarmSwitch(engine, uid) for uid in alarms if uid not in switches]
        for switch in new:
            switches[switch.uid] = switch
        if new:
            async_add_entities(new)
        registry = er.async_get(hass)
        for uid in [uid for uid in switches if uid not in alarms]:
            switch = switches.pop(uid)
            hass.async_create_task(switch.async_remove())
            if registry.async_get(switch.entity_id):
                registry.async_remove(switch.entity_id)
        for switch in switches.values():
            if switch.hass is not None:
                switch.async_write_ha_state()

    sync()
    hass.data.setdefault(f"{DOMAIN}_unsub", []).append(
        async_dispatcher_connect(hass, SIGNAL_UPDATED, sync)
    )


class AlarmSwitch(SwitchEntity):
    _attr_icon = "mdi:alarm"
    _attr_should_poll = False

    def __init__(self, engine: Engine, uid: str) -> None:
        self.engine = engine
        self.uid = uid
        self._attr_unique_id = f"alarm_{uid}"

    @property
    def _entry(self):
        assert self.engine.calendar
        return self.engine.calendar.entries.get(self.uid)

    @property
    def available(self) -> bool:
        return self._entry is not None

    @property
    def name(self) -> str:
        entry = self._entry
        if entry is None:
            return "Wecker"
        assert self.engine.calendar
        when = entry.start.astimezone(self.engine.calendar.tz).strftime("%H:%M")
        return f"{entry.summary} {when}"

    @property
    def is_on(self) -> bool:
        entry = self._entry
        return entry is not None and not entry.cancelled

    @property
    def extra_state_attributes(self) -> dict[str, Any]:
        entry = self._entry
        assert self.engine.calendar
        return self.engine.calendar.item(entry) if entry else {}

    async def async_turn_on(self, **kwargs: Any) -> None:
        await self.engine.alarm_set_enabled(Target(ids=[self.uid]), True)

    async def async_turn_off(self, **kwargs: Any) -> None:
        await self.engine.alarm_set_enabled(Target(ids=[self.uid]), False)
