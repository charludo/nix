"""Config flow for closest_intent.

YAML-only for now: ``async_step_import`` accepts whatever YAML stuffed
into ``data`` and creates a single config entry. The user-facing config
flow (``async_step_user``) just refers them to YAML.
"""

from __future__ import annotations

from typing import Any

from homeassistant import config_entries

from .const import DOMAIN


class ClosestIntentConfigFlow(config_entries.ConfigFlow, domain=DOMAIN):
    """Handle a config flow for closest_intent."""

    VERSION = 1

    async def async_step_import(self, import_data: dict[str, Any]) -> Any:
        """Handle a YAML import."""
        await self.async_set_unique_id(DOMAIN)
        self._abort_if_unique_id_configured(updates=import_data)
        return self.async_create_entry(title="Closest Intent", data=import_data)

    async def async_step_user(self, user_input: dict[str, Any] | None = None) -> Any:
        """User-initiated setup is YAML-only."""
        return self.async_abort(reason="yaml_only")
