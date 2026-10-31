"""The clock's notification indicator."""

from __future__ import annotations

from typing import Any

from homeassistant.components.switch import SwitchEntity
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from . import EchoWallClockConfigEntry
from .entity import ClockEntity


async def async_setup_entry(
    hass: HomeAssistant,
    entry: EchoWallClockConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    async_add_entities([IndicatorSwitch(entry.runtime_data, "indicator")])


class IndicatorSwitch(ClockEntity, SwitchEntity):
    """On is what an Echo does for a new notification; kept across reconnects."""

    @property
    def is_on(self) -> bool:
        return self.runtime.clock.state.indicator

    async def async_turn_on(self, **kwargs: Any) -> None:
        await self.runtime.clock.set_indicator(True)

    async def async_turn_off(self, **kwargs: Any) -> None:
        await self.runtime.clock.set_indicator(False)
