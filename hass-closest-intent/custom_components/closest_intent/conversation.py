"""Closest-intent conversation entity.

Pipeline:
    user_input.text  ──► fuzzy match against `conversation.intents` patterns
                     ──► extract slot text from the user's utterance
                     ──► substitute it into the matched canonical sentence
                     ──► hand off to HA's default agent via async_converse

The default agent then does standard Hassil parsing: it resolves slot
lists in the user's chosen language, validates types, and dispatches the
intent. We never call ``intent.async_handle`` ourselves, so anything HA
supports — ``intent_script``, integrations registering intents, future
mechanisms — works transparently.
"""

from __future__ import annotations

import logging

from homeassistant.components import conversation
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers import intent as intent_helper
from homeassistant.helpers.entity_platform import AddEntitiesCallback

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
from .matching import (
    Candidate,
    build_canonical,
    expand_pattern,
    extract_slots,
    find_best,
)

_LOGGER = logging.getLogger(__name__)


async def async_setup_entry(
    hass: HomeAssistant,
    entry: ConfigEntry,
    async_add_entities: AddEntitiesCallback,
) -> None:
    """Set up the closest-intent conversation entity from a config entry."""
    data = entry.data
    options = entry.options or {}

    def opt(key, default):
        return options.get(key, data.get(key, default))

    agent = ClosestIntentAgent(
        hass,
        threshold=opt(CONF_THRESHOLD, DEFAULT_THRESHOLD),
        expansion_cap=opt(CONF_EXPANSION_CAP, DEFAULT_EXPANSION_CAP),
        allowlist=opt(CONF_ALLOWLIST, None),
        include_builtins=opt(CONF_INCLUDE_BUILTINS, DEFAULT_INCLUDE_BUILTINS),
        slot_extraction=opt(CONF_SLOT_EXTRACTION, DEFAULT_SLOT_EXTRACTION),
        base_agent_id=opt(CONF_BASE_AGENT, DEFAULT_BASE_AGENT),
    )
    async_add_entities([agent])


class ClosestIntentAgent(conversation.ConversationEntity):
    """Forwarding fuzzy-match conversation entity."""

    _attr_has_entity_name = True
    _attr_name = "Closest Intent"
    _attr_supported_features = conversation.ConversationEntityFeature.CONTROL

    def __init__(
        self,
        hass: HomeAssistant,
        *,
        threshold: int,
        expansion_cap: int,
        allowlist: list[str] | None,
        include_builtins: bool,
        slot_extraction: bool,
        base_agent_id: str,
    ) -> None:
        self.hass = hass
        self._threshold = threshold
        self._expansion_cap = expansion_cap
        self._allowlist = set(allowlist) if allowlist else None
        self._include_builtins = include_builtins
        self._slot_extraction = slot_extraction
        self._base_agent_id = base_agent_id
        self._candidates: list[Candidate] = []
        self._attr_unique_id = "closest_intent_agent"

    @property
    def supported_languages(self) -> list[str] | str:
        return conversation.MATCH_ALL

    async def async_added_to_hass(self) -> None:
        await super().async_added_to_hass()
        # Rebuild on a worker thread: when `include_builtins=true` we read
        # the `home_assistant_intents` package data via a sync `open()`,
        # which HA escalates to an error if it happens on the event loop.
        await self.hass.async_add_executor_job(self._rebuild_candidates)

    def _gather_intents(self) -> dict[str, list[str]]:
        """Collect patterns from `conversation.intents` (and optionally HA built-ins)."""
        gathered: dict[str, list[str]] = {}

        conv_intents = self.hass.data.get(DOMAIN, {}).get(KEY_CONVERSATION_INTENTS, {})
        for name, patterns in conv_intents.items():
            if isinstance(patterns, str):
                gathered[name] = [patterns]
            else:
                gathered[name] = list(patterns)

        if self._include_builtins:
            try:
                from home_assistant_intents import get_intents  # type: ignore

                language = self.hass.config.language or "en"
                builtin = get_intents(language) or {}
                for name, payload in (builtin.get("intents") or {}).items():
                    if name in gathered:
                        continue
                    sentences: list[str] = []
                    for block in payload.get("data") or []:
                        sentences.extend(block.get("sentences") or [])
                    if sentences:
                        gathered[name] = sentences
            except Exception:  # pragma: no cover
                _LOGGER.warning(
                    "closest_intent: include_builtins=true but home_assistant_intents "
                    "is unavailable; skipping built-in patterns"
                )

        if self._allowlist is not None:
            gathered = {k: v for k, v in gathered.items() if k in self._allowlist}

        return gathered

    def _rebuild_candidates(self) -> None:
        self._candidates.clear()
        intents = self._gather_intents()

        for intent_name, patterns in intents.items():
            for idx, pat in enumerate(patterns):
                for text, slot_names in expand_pattern(pat, self._expansion_cap):
                    self._candidates.append(
                        Candidate(
                            intent=intent_name,
                            pattern_idx=idx,
                            text=text,
                            slot_names=slot_names,
                        )
                    )

        _LOGGER.info(
            "closest_intent: built %d candidates across %d intents (builtins=%s)",
            len(self._candidates),
            len(intents),
            self._include_builtins,
        )

    async def async_process(
        self, user_input: conversation.ConversationInput
    ) -> conversation.ConversationResult:
        """Match, reconstruct, forward.

        On any failure path — no fuzzy match, slot extraction ambiguous,
        unexpected exception — we fall through to the base agent with
        the user's *original* text. That way the user gets the base
        agent's locale-aware "I didn't understand that" response (or it
        gets a chance to handle the utterance some other way) rather
        than our bare error string.
        """
        try:
            canonical = self._best_canonical(user_input)
        except Exception:  # pragma: no cover
            _LOGGER.exception(
                "closest_intent: unexpected error matching %r", user_input.text
            )
            canonical = None

        # Fall back to the user's raw text if we couldn't produce a
        # cleaned-up canonical sentence. Either way we forward to the
        # base agent and let it run its standard pipeline.
        forwarded_text = canonical if canonical is not None else user_input.text

        try:
            return await conversation.async_converse(
                hass=self.hass,
                text=forwarded_text,
                conversation_id=user_input.conversation_id,
                context=user_input.context,
                language=user_input.language,
                agent_id=self._base_agent_id,
            )
        except Exception:
            _LOGGER.exception(
                "closest_intent: forwarding to %s failed", self._base_agent_id
            )
            return _no_match(user_input)

    def _best_canonical(
        self, user_input: conversation.ConversationInput
    ) -> str | None:
        """Find the best-matching candidate and rebuild its canonical text.

        Returns ``None`` when nothing scores above threshold or when slot
        extraction fails. The caller will forward the user's original
        text instead.
        """
        match = find_best(user_input.text, self._candidates, self._threshold)
        if match is None:
            _LOGGER.debug(
                "closest_intent: no match for %r above %d, passthrough",
                user_input.text,
                self._threshold,
            )
            return None

        candidate, score_value = match

        if candidate.has_slots:
            if not self._slot_extraction:
                return None
            captured = extract_slots(user_input.text, candidate)
            if captured is None:
                _LOGGER.debug(
                    "closest_intent: matched %s (score=%d) but slot extraction failed, passthrough",
                    candidate.intent,
                    score_value,
                )
                return None
        else:
            captured = []

        canonical = build_canonical(candidate, captured)
        _LOGGER.info(
            "closest_intent: %r → %s (score=%d) → forwarding %r to %s",
            user_input.text,
            candidate.intent,
            score_value,
            canonical,
            self._base_agent_id,
        )
        return canonical


def _no_match(
    user_input: conversation.ConversationInput,
) -> conversation.ConversationResult:
    """Return NO_INTENT_MATCH so the pipeline can cascade."""
    response = intent_helper.IntentResponse(language=user_input.language)
    response.async_set_error(
        intent_helper.IntentResponseErrorCode.NO_INTENT_MATCH,
        "No matching intent.",
    )
    return conversation.ConversationResult(
        response=response,
        conversation_id=user_input.conversation_id,
    )
