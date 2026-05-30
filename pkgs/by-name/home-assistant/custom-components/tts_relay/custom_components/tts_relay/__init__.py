"""Re-route assist_pipeline TTS responses to a Sonos via snapshot/restore.

Wyoming satellites without a usable speaker still receive TTS audio
over the wyoming protocol as raw PCM. There's no URL the satellite
exposes back to HA, and the pipeline's ``tts-end`` event (which does
carry ``tts_output.url``) is delivered only via an in-process callback
on the satellite entity — not on the HA event bus. A pure-YAML
automation therefore can't see the URL.

This integration wraps ``AssistSatelliteEntity._internal_on_pipeline_event``
so that when a configured satellite emits ``TTS_END``, we play the
audio on a target Sonos. ``media_player.play_media``'s ``announce:
true`` is *not* used because Sonos routes it through the local
WebSocket API which requires periodic Sonos-cloud OAuth — useless
behind a firewall and times out for 5+ s on every call. Instead we
emulate ducking with ``sonos.snapshot`` / ``sonos.restore``, which run
purely over local UPnP.

Voice-effect markers
--------------------
Intent handlers can annotate their response with a card of type
``voice_effect`` whose ``title`` names a category:

    card:
      type: voice_effect
      title: acknowledge | silent | timer | reminder | alarmclock

On the matching satellite's ``TTS_END``:

* ``silent``     — drop the audio; play nothing. Use for intents whose
                   action already produces audible feedback (music
                   starting on the same Sonos).
* ``<category>`` — substitute the configured sound URL for that
                   category (from the ``sounds:`` config) and play that
                   on the target Sonos with the usual snapshot/restore
                   ducking.
* unset / unknown — relay the synthesized TTS audio (default behaviour).

The chat path is unaffected: HA's chat UI renders only ``card.simple``,
so a ``voice_effect`` card is invisible there and the original speech
text is shown verbatim.

Sequence on TTS_END (when something needs to play):
  1. If target is currently ``playing``: ``sonos.snapshot``.
  2. Set volume (optional).
  3. ``media_player.play_media`` with the chosen URL.
  4. If we snapshotted: wait for state to leave ``playing`` (clip
     finished), then ``sonos.restore``.
"""

from __future__ import annotations

import asyncio
import logging

import voluptuous as vol
from homeassistant.const import CONF_TARGET
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers import config_validation as cv
from homeassistant.helpers.event import async_track_state_change_event
from homeassistant.helpers.network import NoURLAvailableError, get_url
from homeassistant.helpers.typing import ConfigType

DOMAIN = "tts_relay"
CONF_SATELLITE = "satellite"
CONF_VOLUME = "volume"
CONF_ROUTES = "routes"
CONF_SOUNDS = "sounds"

# Card type intent handlers use to flag a voice-effect override.
VOICE_EFFECT_CARD_TYPE = "voice_effect"
# Special title that means "drop the TTS audio, play nothing".
SILENT_EFFECT = "silent"

# Safety cap so a stuck-pending state never leaks a snapshot. TTS
# responses are short (seconds); 60 s is generous.
_RESTORE_TIMEOUT = 60.0

_LOGGER = logging.getLogger(__name__)

ROUTE_SCHEMA = vol.Schema(
    {
        vol.Required(CONF_SATELLITE): cv.entity_id,
        vol.Required(CONF_TARGET): cv.entity_id,
        vol.Optional(CONF_VOLUME): vol.All(vol.Coerce(float), vol.Range(min=0.0, max=1.0)),
    }
)

# Accept either a bare list of routes (legacy form) or a dict with
# `routes:` + optional `sounds:`. Normalised to the dict form below.
DICT_SCHEMA = vol.Schema(
    {
        vol.Required(CONF_ROUTES): vol.All(cv.ensure_list, [ROUTE_SCHEMA]),
        vol.Optional(CONF_SOUNDS, default={}): {cv.string: cv.string},
    }
)


def _config_schema(value):
    if isinstance(value, list):
        return {CONF_ROUTES: [ROUTE_SCHEMA(r) for r in value], CONF_SOUNDS: {}}
    return DICT_SCHEMA(value)


CONFIG_SCHEMA = vol.Schema(
    {DOMAIN: _config_schema},
    extra=vol.ALLOW_EXTRA,
)


def _absolutise(hass: HomeAssistant, url: str) -> str | None:
    """Sonos needs a fully-qualified URL. HA's TTS manager hands out
    paths like ``/api/tts_proxy/<hash>.mp3``; prepend HA's base URL."""
    if not url:
        return None
    if url.startswith(("http://", "https://")):
        return url
    try:
        base = get_url(hass, allow_internal=True, prefer_external=False)
    except NoURLAvailableError:
        _LOGGER.error("tts_relay: no HA base URL configured; cannot relay %s", url)
        return None
    return base.rstrip("/") + url


async def _play_on_target(hass: HomeAssistant, route: dict, url: str, content_type: str) -> None:
    target = route[CONF_TARGET]
    state = hass.states.get(target)
    was_playing = state is not None and state.state == "playing"

    if was_playing:
        try:
            await hass.services.async_call(
                "sonos", "snapshot", {"entity_id": target}, blocking=True
            )
        except Exception:
            _LOGGER.exception("tts_relay: snapshot failed for %s", target)
            was_playing = False  # Don't try to restore something we couldn't save.

    volume = route.get(CONF_VOLUME)
    if volume is not None:
        try:
            await hass.services.async_call(
                "media_player",
                "volume_set",
                {"entity_id": target, "volume_level": volume},
                blocking=True,
            )
        except Exception:
            _LOGGER.exception("tts_relay: volume_set failed for %s", target)

    try:
        await hass.services.async_call(
            "media_player",
            "play_media",
            {
                "entity_id": target,
                "media_content_id": url,
                "media_content_type": content_type,
            },
            blocking=True,
        )
    except Exception:
        _LOGGER.exception("tts_relay: play_media failed for %s", target)
        if was_playing:
            await _restore(hass, target)
        return

    if not was_playing:
        return

    # Wait for the clip to finish (target leaves ``playing``). Attach
    # the listener before re-reading the state to avoid the
    # play-ends-between-call-and-listen race.
    done: asyncio.Event = asyncio.Event()

    @callback
    def _on_change(event):
        new_state = event.data.get("new_state")
        if new_state is not None and new_state.state != "playing":
            done.set()

    unsub = async_track_state_change_event(hass, [target], _on_change)
    try:
        current = hass.states.get(target)
        if current is not None and current.state != "playing":
            done.set()
        try:
            await asyncio.wait_for(done.wait(), timeout=_RESTORE_TIMEOUT)
        except asyncio.TimeoutError:
            _LOGGER.warning(
                "tts_relay: %s still playing after %.0fs; restoring anyway",
                target,
                _RESTORE_TIMEOUT,
            )
    finally:
        unsub()

    await _restore(hass, target)


async def _restore(hass: HomeAssistant, target: str) -> None:
    try:
        await hass.services.async_call(
            "sonos", "restore", {"entity_id": target}, blocking=True
        )
    except Exception:
        _LOGGER.exception("tts_relay: restore failed for %s", target)


def _read_voice_effect(intent_output: dict | None) -> str | None:
    """Pull the voice_effect marker out of the INTENT_END event payload.

    Returns the effect name (``acknowledge``, ``silent``, ...) or None.
    Looks for a ``card.voice_effect.title`` set by intent_script via
    `lib.ha.voice.acknowledgeAction` / `silentAction`.
    """
    if not intent_output:
        return None
    response = intent_output.get("response") or {}
    card = response.get("card") or {}
    effect = card.get(VOICE_EFFECT_CARD_TYPE)
    if not effect:
        return None
    title = (effect.get("title") or "").strip().lower()
    return title or None


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    cfg = config.get(DOMAIN)
    if not cfg:
        return True

    routes = cfg.get(CONF_ROUTES) or []
    if not routes:
        return True

    sounds: dict[str, str] = cfg.get(CONF_SOUNDS) or {}

    by_satellite = {r[CONF_SATELLITE]: r for r in routes}

    # One relay at a time per route, so a fast second TTS doesn't race
    # the first one's restore. Queue-style: subsequent TTSes wait their
    # turn instead of stomping on the snapshot.
    locks: dict[str, asyncio.Lock] = {
        r[CONF_SATELLITE]: asyncio.Lock() for r in routes
    }

    # Per-satellite "last seen INTENT_END effect", consumed by the
    # immediately-following TTS_END. assist_satellite runs at most one
    # pipeline at a time per entity, so there's no concurrency risk.
    pending_effects: dict[str, str | None] = {}

    # Imported lazily so HA's manifest dependency resolution gets a
    # chance to load assist_satellite first.
    from homeassistant.components.assist_pipeline.pipeline import PipelineEventType
    from homeassistant.components.assist_satellite.entity import AssistSatelliteEntity

    original = AssistSatelliteEntity._internal_on_pipeline_event

    async def _run(satellite_id: str, route: dict, url: str, content_type: str) -> None:
        async with locks[satellite_id]:
            await _play_on_target(hass, route, url, content_type)

    def patched(self, event):
        original(self, event)
        data = event.data or {}

        # Log STT transcripts (and conversation responses) to HA's
        # logbook for every satellite — the mobile-app chat view shows
        # these natively but the satellite path doesn't. Useful for
        # debugging "what did Wassermelone actually get recognised as".
        if event.type == PipelineEventType.STT_END:
            text = ((data.get("stt_output") or {}).get("text") or "").strip()
            if text:
                _LOGGER.info("STT (%s): %r", self.entity_id, text)
                hass.bus.async_fire(
                    "logbook_entry",
                    {
                        "name": "Assist",
                        "message": f'heard: "{text}"',
                        "domain": "assist_satellite",
                        "entity_id": self.entity_id,
                    },
                )
        elif event.type == PipelineEventType.INTENT_END:
            intent_output = data.get("intent_output") or {}
            speech = (
                ((intent_output.get("response") or {}).get("speech") or {})
                .get("plain", {})
                .get("speech")
            )
            if speech:
                _LOGGER.info("Intent (%s): %r", self.entity_id, speech)
                hass.bus.async_fire(
                    "logbook_entry",
                    {
                        "name": "Assist",
                        "message": f'replied: "{speech}"',
                        "domain": "assist_satellite",
                        "entity_id": self.entity_id,
                    },
                )
            # Capture the voice_effect marker (if any) for the upcoming
            # TTS_END to consume.
            captured = _read_voice_effect(intent_output)
            pending_effects[self.entity_id] = captured
            _LOGGER.debug(
                "tts_relay: INTENT_END on %s — voice_effect=%r, card=%r",
                self.entity_id,
                captured,
                (intent_output.get("response") or {}).get("card"),
            )

        route = by_satellite.get(self.entity_id)
        if route is None:
            return
        if event.type != PipelineEventType.TTS_END:
            return

        # Consume the marker the matching INTENT_END left behind. If
        # none, fall through to the default TTS-relay behaviour.
        effect = pending_effects.pop(self.entity_id, None)
        _LOGGER.debug(
            "tts_relay: TTS_END on %s — effect=%r, configured sounds=%s",
            self.entity_id,
            effect,
            sorted(sounds.keys()),
        )

        if effect == SILENT_EFFECT:
            _LOGGER.debug("tts_relay: silent effect for %s; dropping TTS", self.entity_id)
            return

        if effect:
            sound_url = sounds.get(effect)
            if not sound_url:
                _LOGGER.warning(
                    "tts_relay: intent on %s requested effect %r but no sound is "
                    "configured for it — falling back to TTS",
                    self.entity_id,
                    effect,
                )
            else:
                url = _absolutise(hass, sound_url)
                if url:
                    _LOGGER.debug(
                        "tts_relay: playing effect %r on %s -> %s",
                        effect, route[CONF_TARGET], url,
                    )
                    hass.async_create_task(_run(self.entity_id, route, url, "music"))
                    return

        tts_output = data.get("tts_output") or {}
        url = _absolutise(hass, tts_output.get("url"))
        if not url:
            return
        # Sonos rejects MIME types like ``audio/x-wav``; the HA Sonos
        # integration only accepts the generic media class strings
        # (``music``, ``audio``, ...). The actual format is determined
        # by the URL/file content, not this field.
        hass.async_create_task(_run(self.entity_id, route, url, "music"))

    AssistSatelliteEntity._internal_on_pipeline_event = patched

    _LOGGER.info(
        "tts_relay: relaying TTS for %s; configured effects: %s",
        ", ".join(f"{k} -> {v[CONF_TARGET]}" for k, v in by_satellite.items()),
        sorted(sounds.keys()) or "(none)",
    )
    return True
