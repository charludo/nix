"""One sensor per timer: when it ends (the frontend counts down), all fields
as attributes. Created and removed with the timer. With a calendar, also
"next alarm"."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any

from homeassistant.components.sensor import SensorDeviceClass, SensorEntity
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers import entity_registry as er
from homeassistant.helpers.dispatcher import async_dispatcher_connect
from homeassistant.helpers.entity_platform import AddEntitiesCallback
from homeassistant.helpers.event import async_track_time_interval

from .const import DOMAIN, KIND_ALARM, SIGNAL_UPDATED
from .engine import Engine, Target
from .timers import Timer


async def async_setup_platform(
    hass: HomeAssistant, config, async_add_entities: AddEntitiesCallback, discovery_info=None
) -> None:
    engine: Engine = hass.data[DOMAIN]
    sensors: dict[str, TimerSensor] = {}

    # Leftovers from timers that ended while HA was down.
    registry = er.async_get(hass)
    for entry in list(registry.entities.values()):
        if (
            entry.platform == DOMAIN
            and entry.domain == "sensor"
            and entry.unique_id.startswith("timer_")
            and entry.unique_id.removeprefix("timer_") not in engine.book.timers
        ):
            registry.async_remove(entry.entity_id)

    @callback
    def sync(_changed_id: str | None = None) -> None:
        current = engine.book.timers
        new = [TimerSensor(engine, t) for tid, t in current.items() if tid not in sensors]
        for sensor in new:
            sensors[sensor.timer.id] = sensor
        if new:
            async_add_entities(new)
        for tid in [tid for tid in sensors if tid not in current]:
            sensor = sensors.pop(tid)
            hass.async_create_task(sensor.async_remove_for_good())
        for tid, sensor in sensors.items():
            # A snoozed timer comes back as a new object with the same id.
            sensor.timer = current[tid]
            if sensor.hass is not None:
                sensor.async_write_ha_state()

    sync()
    hass.data.setdefault(f"{DOMAIN}_unsub", []).append(
        async_dispatcher_connect(hass, SIGNAL_UPDATED, sync)
    )
    if engine.calendar:
        async_add_entities([NextAlarmSensor(engine)])


class TimerSensor(SensorEntity):
    _attr_device_class = SensorDeviceClass.TIMESTAMP
    _attr_icon = "mdi:timer-outline"
    _attr_should_poll = False

    def __init__(self, engine: Engine, timer: Timer) -> None:
        self.engine = engine
        self.timer = timer
        self._attr_unique_id = f"timer_{timer.id}"
        self.entity_id = f"sensor.{DOMAIN}_timer_{timer.id}"

    @property
    def name(self) -> str:
        if self.timer.label:
            return f"Timer {self.timer.label}"
        minutes, seconds = divmod(int(self.timer.duration), 60)
        hours, minutes = divmod(minutes, 60)
        return (
            f"Timer {hours}:{minutes:02d}:{seconds:02d}"
            if hours
            else f"Timer {minutes}:{seconds:02d}"
        )

    @property
    def native_value(self) -> datetime | None:
        if self.timer.ends_at is None:
            return None
        return datetime.fromtimestamp(self.timer.ends_at, UTC)

    @property
    def extra_state_attributes(self) -> dict[str, Any]:
        item = self.engine.item(self.timer)
        item.pop("entity_id", None)
        return item

    async def async_remove_for_good(self) -> None:
        await self.async_remove()
        registry = er.async_get(self.hass)
        if registry.async_get(self.entity_id):
            registry.async_remove(self.entity_id)


class NextAlarmSensor(SensorEntity):
    """When the next alarm rings (disabled and skipped ones left out)."""

    _attr_device_class = SensorDeviceClass.TIMESTAMP
    _attr_icon = "mdi:alarm"
    _attr_should_poll = False
    _attr_name = "Next alarm"
    _attr_unique_id = "next_alarm"

    def __init__(self, engine: Engine) -> None:
        self.engine = engine
        self.entity_id = f"sensor.{DOMAIN}_next_alarm"
        self._item: dict | None = None

    async def async_added_to_hass(self) -> None:
        @callback
        def update(_changed: str | datetime | None = None) -> None:
            self._refresh()
            self.async_write_ha_state()

        self.async_on_remove(async_dispatcher_connect(self.hass, SIGNAL_UPDATED, update))
        # Rings move past without any change: refresh once a minute.
        self.async_on_remove(async_track_time_interval(self.hass, update, timedelta(minutes=1)))
        self._refresh()

    def _refresh(self) -> None:
        items = self.engine.query(Target(), kind=KIND_ALARM).items
        upcoming = [i for i in items if i["next_ring"]]
        self._item = min(upcoming, key=lambda i: i["next_ring"]) if upcoming else None

    @property
    def native_value(self) -> datetime | None:
        return datetime.fromisoformat(self._item["next_ring"]) if self._item else None

    @property
    def extra_state_attributes(self) -> dict[str, Any]:
        return dict(self._item) if self._item else {}
