"""Single sensor exposing the most recently rendered shopping list.

State = item count, attribute ``markdown`` = formatted list, attribute
``supermarket`` = which supermarket it was rendered for. Each call to
``grocery_categorize.refresh`` overwrites whatever was there before.
"""

from __future__ import annotations

import logging
from typing import Any

from homeassistant.components.sensor import SensorEntity
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers.entity_platform import AddEntitiesCallback
from homeassistant.helpers.restore_state import RestoreEntity
from homeassistant.helpers.typing import ConfigType, DiscoveryInfoType

from .const import (
    ATTR_GENERATED_AT,
    ATTR_MARKDOWN,
    ATTR_SUPERMARKET,
    DATA_LISTENERS,
    DATA_RESULT,
    DOMAIN,
)


_LOGGER = logging.getLogger(__name__)


async def async_setup_platform(
    hass: HomeAssistant,
    config: ConfigType,
    async_add_entities: AddEntitiesCallback,
    discovery_info: DiscoveryInfoType | None = None,
) -> None:
    async_add_entities([ShoppingListSensor(hass)])


class ShoppingListSensor(SensorEntity, RestoreEntity):
    _attr_should_poll = False
    _attr_icon = "mdi:cart"
    _attr_name = "Einkaufsliste"
    _attr_unique_id = "grocery_categorize_shopping_list"

    def __init__(self, hass: HomeAssistant) -> None:
        self._hass = hass

    async def async_added_to_hass(self) -> None:
        await super().async_added_to_hass()
        self._hass.data[DOMAIN][DATA_LISTENERS].append(self._handle_update)
        # Restore the previously rendered list across HA restarts so the
        # markdown card doesn't reset to the placeholder. Only restore if
        # no fresh refresh has happened yet this boot.
        if not self._hass.data[DOMAIN][DATA_RESULT]:
            last = await self.async_get_last_state()
            if last is not None and last.attributes:
                try:
                    count = int(last.state)
                except (TypeError, ValueError):
                    count = 0
                self._hass.data[DOMAIN][DATA_RESULT] = {
                    "supermarket": last.attributes.get(ATTR_SUPERMARKET, ""),
                    "markdown": last.attributes.get(ATTR_MARKDOWN, ""),
                    "generated_at": last.attributes.get(ATTR_GENERATED_AT, ""),
                    "count": count,
                }

    async def async_will_remove_from_hass(self) -> None:
        listeners = self._hass.data[DOMAIN][DATA_LISTENERS]
        if self._handle_update in listeners:
            listeners.remove(self._handle_update)

    @callback
    def _handle_update(self) -> None:
        self.async_write_ha_state()

    @property
    def _result(self) -> dict[str, Any]:
        return self._hass.data[DOMAIN][DATA_RESULT]

    @property
    def native_value(self) -> int:
        return self._result.get("count", 0)

    @property
    def extra_state_attributes(self) -> dict[str, Any]:
        r = self._result
        return {
            ATTR_SUPERMARKET: r.get("supermarket", ""),
            ATTR_MARKDOWN: r.get("markdown", "_Tippe einen Markt an, um die Liste zu generieren._"),
            ATTR_GENERATED_AT: r.get("generated_at", ""),
        }
