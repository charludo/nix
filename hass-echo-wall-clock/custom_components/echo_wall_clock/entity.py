"""The base for this integration's entities: one device per clock."""

from __future__ import annotations

from homeassistant.helpers.device_registry import DeviceInfo
from homeassistant.helpers.entity import Entity

from .const import DOMAIN
from .runtime import ClockRuntime


class ClockEntity(Entity):
    _attr_has_entity_name = True
    _attr_should_poll = False

    def __init__(self, runtime: ClockRuntime, key: str) -> None:
        self.runtime = runtime
        self._attr_unique_id = f"{runtime.address}_{key}"
        self._attr_translation_key = key
        self._attr_device_info = DeviceInfo(identifiers={(DOMAIN, runtime.address)})

    async def async_added_to_hass(self) -> None:
        self.async_on_remove(self.runtime.async_add_listener(self._refresh))

    def _refresh(self) -> None:
        self.async_write_ha_state()
