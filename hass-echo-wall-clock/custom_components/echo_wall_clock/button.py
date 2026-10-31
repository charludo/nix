"""Send the time now (it's also sent on every connect and every half hour)."""

from __future__ import annotations

from homeassistant.components.button import ButtonEntity
from homeassistant.const import EntityCategory
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from . import EchoWallClockConfigEntry
from .entity import ClockEntity


async def async_setup_entry(
    hass: HomeAssistant,
    entry: EchoWallClockConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    async_add_entities([SyncTimeButton(entry.runtime_data, "sync_time")])


class SyncTimeButton(ClockEntity, ButtonEntity):
    _attr_entity_category = EntityCategory.CONFIG

    @property
    def available(self) -> bool:
        return self.runtime.connected

    async def async_press(self) -> None:
        await self.runtime.clock.sync_time()
