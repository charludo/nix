"""The next timer, alarm and reminder, each with the full list as an attribute."""

from __future__ import annotations

from datetime import datetime

from homeassistant.components.sensor import SensorDeviceClass, SensorEntity
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from . import EchoWallClockConfigEntry
from .const import ATTR_ALERTS, KINDS
from .entity import ClockEntity


async def async_setup_entry(
    hass: HomeAssistant,
    entry: EchoWallClockConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    async_add_entities(NextAlertSensor(entry.runtime_data, kind) for kind in KINDS)


class NextAlertSensor(ClockEntity, SensorEntity):
    """When the next alert of one kind is (or was) due; ringing ones count."""

    _attr_device_class = SensorDeviceClass.TIMESTAMP

    def __init__(self, runtime, kind: str) -> None:
        super().__init__(runtime, f"next_{kind}")
        self.kind = kind.upper()

    def _alerts(self):
        return sorted(
            (a for a in self.runtime.clock.state.alerts.values() if a.kind == self.kind),
            key=lambda a: a.at,
        )

    @property
    def native_value(self) -> datetime | None:
        alerts = self._alerts()
        return alerts[0].at if alerts else None

    @property
    def extra_state_attributes(self) -> dict:
        return {
            ATTR_ALERTS: [
                {**a.as_dict(), "ringing": self.runtime.ringing(a)} for a in self._alerts()
            ]
        }
