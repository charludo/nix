"""Closest-intent fuzzy-fallback conversation agent for Home Assistant.

When the user's spoken input doesn't match any pattern Hassil knows,
this agent fuzzy-matches against ``conversation.intents`` (your
user-defined patterns), reconstructs a canonical sentence with the
slot text the user actually spoke, and forwards it to HA's default
conversation agent. HA then validates slot lists, dispatches the
intent, and runs the action — same as if the user had said the canonical
phrase exactly.
"""

from __future__ import annotations

import logging

import voluptuous as vol

from homeassistant.config_entries import SOURCE_IMPORT, ConfigEntry
from homeassistant.const import Platform
from homeassistant.core import HomeAssistant
import homeassistant.helpers.config_validation as cv
from homeassistant.helpers.typing import ConfigType

from .const import (
    CONF_ALLOWLIST,
    CONF_BASE_AGENT,
    CONF_EXPANSION_CAP,
    CONF_INCLUDE_BUILTINS,
    CONF_SLOT_EXTRACTION,
    CONF_THRESHOLD,
    DEFAULT_BASE_AGENT,
    DEFAULT_EXPANSION_CAP,
    DEFAULT_INCLUDE_BUILTINS,
    DEFAULT_SLOT_EXTRACTION,
    DEFAULT_THRESHOLD,
    DOMAIN,
    KEY_CONVERSATION_INTENTS,
)

_LOGGER = logging.getLogger(__name__)

CONFIG_SCHEMA = vol.Schema(
    {
        DOMAIN: vol.Schema(
            {
                vol.Optional(CONF_THRESHOLD, default=DEFAULT_THRESHOLD): vol.All(
                    vol.Coerce(int), vol.Range(min=0, max=100)
                ),
                vol.Optional(CONF_EXPANSION_CAP, default=DEFAULT_EXPANSION_CAP): vol.All(
                    vol.Coerce(int), vol.Range(min=0)
                ),
                # Restrict matching to specific intent names. Default = all.
                vol.Optional(CONF_ALLOWLIST, default=None): vol.Any(
                    None, [cv.string]
                ),
                # Also fuzzy-match HA's built-in intent patterns
                # (HassTurnOn etc.) loaded from `home_assistant_intents`.
                vol.Optional(
                    CONF_INCLUDE_BUILTINS, default=DEFAULT_INCLUDE_BUILTINS
                ): cv.boolean,
                vol.Optional(
                    CONF_SLOT_EXTRACTION, default=DEFAULT_SLOT_EXTRACTION
                ): cv.boolean,
                # Conversation entity to forward the canonical sentence to
                # after a fuzzy match. Default is HA's bundled agent.
                vol.Optional(CONF_BASE_AGENT, default=DEFAULT_BASE_AGENT): cv.string,
            }
        )
    },
    extra=vol.ALLOW_EXTRA,
)

PLATFORMS: list[Platform] = [Platform.CONVERSATION]


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    """Capture the user's `conversation.intents` and bootstrap the agent.

    HA processes ``conversation.intents`` into IntentHandlers shortly
    after this hook runs, losing the original sentence patterns. We
    stash a copy in ``hass.data`` so the conversation entity can read
    them at setup time.
    """
    conv_intents = (config.get("conversation") or {}).get("intents") or {}
    hass.data.setdefault(DOMAIN, {})[KEY_CONVERSATION_INTENTS] = dict(conv_intents)

    if DOMAIN not in config:
        return True

    hass.async_create_task(
        hass.config_entries.flow.async_init(
            DOMAIN,
            context={"source": SOURCE_IMPORT},
            data=dict(config[DOMAIN]),
        )
    )
    return True


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """Set up the conversation entity from a config entry."""
    hass.data.setdefault(DOMAIN, {})[entry.entry_id] = entry
    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)
    return True


async def async_unload_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """Unload a config entry."""
    unload_ok = await hass.config_entries.async_unload_platforms(entry, PLATFORMS)
    if unload_ok:
        hass.data[DOMAIN].pop(entry.entry_id, None)
    return unload_ok
