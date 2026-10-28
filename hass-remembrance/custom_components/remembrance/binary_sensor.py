"""On while anything rings; the ringing items as attributes."""

from __future__ import annotations

from typing import Any

from homeassistant.components.binary_sensor import BinarySensorEntity
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers.dispatcher import async_dispatcher_connect
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from .const import DOMAIN, SIGNAL_UPDATED
from .engine import Engine


async def async_setup_platform(
    hass: HomeAssistant, config, async_add_entities: AddEntitiesCallback, discovery_info=None
) -> None:
    async_add_entities([RingingSensor(hass.data[DOMAIN])])


class RingingSensor(BinarySensorEntity):
    _attr_name = "Remembrance ringing"
    _attr_unique_id = "ringing"
    _attr_icon = "mdi:bell-ring"
    _attr_should_poll = False

    def __init__(self, engine: Engine) -> None:
        self.engine = engine
        self.entity_id = f"binary_sensor.{DOMAIN}_ringing"

    async def async_added_to_hass(self) -> None:
        @callback
        def update(_changed_id: str | None = None) -> None:
            self.async_write_ha_state()

        self.async_on_remove(async_dispatcher_connect(self.hass, SIGNAL_UPDATED, update))

    @property
    def is_on(self) -> bool:
        return bool(self.engine.ringing())

    @property
    def extra_state_attributes(self) -> dict[str, Any]:
        return {"items": self.engine.ringing_items()}
