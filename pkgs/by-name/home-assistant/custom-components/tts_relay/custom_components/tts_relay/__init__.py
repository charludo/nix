"""Re-route assist_pipeline TTS responses to a Sonos via announce mode.

Wyoming satellites without a usable speaker still receive TTS audio
over the wyoming protocol as raw PCM. There's no URL the satellite
exposes back to HA, and the pipeline's ``tts-end`` event (which does
carry ``tts_output.url``) is delivered only via an in-process callback
on the satellite entity — not on the HA event bus. A pure-YAML
automation therefore can't see the URL.

This integration wraps ``AssistSatelliteEntity._internal_on_pipeline_event``
so that when a configured satellite emits ``TTS_END``, we replay the
audio on a target Sonos using HA's native ``media_player.play_media``
with ``announce: true``. Sonos handles ducking and resume natively
under that flag — much cleaner than juggling ``sonos.snapshot`` /
``sonos.restore`` manually.

Note: the ``audioClip`` cloud check that the speaker's firmware runs
on every announce call will silently delay playback by ~5 s if the
speaker can't reach Sonos cloud. If your speakers are firewalled, use
*reject* (TCP RST) rather than *block* (silent drop) on outbound — the
RST short-circuits the cloud check in ~50 ms instead of timing out.

Voice-effect markers
--------------------
Intent handlers can annotate their response with a card of type
``voice_effect`` whose ``title`` names a category:

    card:
      type: voice_effect
      title: acknowledge | silent | timer | reminder | alarmclock

On the matching satellite's ``TTS_END``:

* ``silent``     — drop the audio; announce nothing. Use for intents
                   whose action already produces audible feedback
                   (music starting on the same Sonos).
* ``<category>`` — announce the configured sound URL for that category
                   (from the ``sounds:`` config) instead of the TTS.
* unset / unknown — announce the synthesized TTS audio (default).

The chat path is unaffected: HA's chat UI renders only ``card.simple``,
so a ``voice_effect`` card is invisible there and the original speech
text is shown verbatim.

Wake-word ducking
-----------------
If a ``duck`` sound is configured, ``RUN_START`` fires a near-silent
audioClip via ``announce: true`` so Sonos's native ducking lowers
playback for the duration of the interaction. The clip is cancelled
on ``TTS_END`` (so the response announce isn't queued behind it) and
defensively on ``RUN_END`` (so an aborted pipeline doesn't strand the
duck on a finite-length clip). Should the cancel fail, the clip's own
duration is the worst-case recovery time.

``RUN_START`` rather than ``WAKE_WORD_END`` because the latter is only
emitted when HA itself runs the wake-word stage. Wyoming satellites
typically detect the wake word on-device and tell HA to start the
pipeline at ``STT``, in which case ``WAKE_WORD_END`` never fires.
"""

from __future__ import annotations

import logging

import voluptuous as vol
from homeassistant.const import CONF_TARGET
from homeassistant.core import HomeAssistant
from homeassistant.helpers import config_validation as cv
from homeassistant.helpers.network import NoURLAvailableError, get_url
from homeassistant.helpers.typing import ConfigType

DOMAIN = "tts_relay"
CONF_SATELLITE = "satellite"
CONF_VOLUME = "volume"
CONF_ROUTES = "routes"
CONF_SOUNDS = "sounds"

# Card type intent handlers use to flag a voice-effect override.
VOICE_EFFECT_CARD_TYPE = "voice_effect"
# Special title that means "drop the TTS audio, announce nothing".
SILENT_EFFECT = "silent"
# Fallback effect for pipeline intent errors other than "no match".
ERROR_EFFECT = "error"
# Sounds key for the near-silent clip fired on wake-word detection,
# used to make Sonos duck music for the duration of an interaction.
DUCK_EFFECT = "duck"
# IntentResponseErrorCode.NO_INTENT_MATCH — "Entschuldigung, das habe
# ich nicht verstanden". We treat it as silent rather than chime
# because "wake word + nothing happens" is the desired UX when the
# user mumbled or the matcher whiffed.
NO_MATCH_ERROR_CODE = "no_intent_match"

SERVICE_SILENCE = "silence"
ATTR_ENTITY_ID = "entity_id"

_LOGGER = logging.getLogger(__name__)

ROUTE_SCHEMA = vol.Schema(
    {
        vol.Required(CONF_SATELLITE): cv.entity_id,
        vol.Required(CONF_TARGET): cv.entity_id,
        vol.Optional(CONF_VOLUME): vol.All(
            vol.Coerce(float), vol.Range(min=0.05, max=1.0)
        ),
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


async def _announce(hass: HomeAssistant, route: dict, url: str) -> None:
    """Fire one ``media_player.play_media`` with ``announce: true``. Sonos
    handles ducking and queue restore natively under that flag."""
    target = route[CONF_TARGET]
    data: dict = {
        "entity_id": target,
        "announce": True,
        "media_content_id": url,
        # Generic media class — actual format is sniffed from the URL.
        "media_content_type": "music",
    }
    volume = route.get(CONF_VOLUME)
    if volume is not None:
        # Sonos audioClip expects volume as int 0–100; our config takes
        # a 0.0–1.0 float for consistency with media_player.volume_set.
        data["extra"] = {"volume": int(volume * 100)}

    try:
        await hass.services.async_call(
            "media_player", "play_media", data, blocking=True
        )
    except Exception:
        _LOGGER.exception("tts_relay: announce failed for %s", target)


async def _cancel_audio_clip(hass: HomeAssistant, entity_id: str) -> None:
    """Send Sonos ``cancelAudioClip`` over the cloud websocket. No-op
    for non-Sonos entities or if no clip is in flight. Used both by
    ``tts_relay.silence`` and by the wake-word duck cleanup."""
    component = hass.data.get("media_player")
    if component is None:
        return
    entity = component.get_entity(entity_id)
    if entity is None:
        return
    # SonosMediaPlayerEntity exposes the underlying SonosSpeaker,
    # which carries the cloud websocket. Non-Sonos players have no
    # speaker attribute; skip them.
    speaker = getattr(entity, "speaker", None)
    websocket = getattr(speaker, "websocket", None) if speaker else None
    if websocket is None:
        return
    try:
        player_id = await websocket.get_player_id()
        await websocket.send_command(
            {
                "namespace": "audioClip:1",
                "command": "cancelAudioClip",
                "playerId": player_id,
            }
        )
    except Exception:
        _LOGGER.exception("tts_relay: cancelAudioClip failed for %s", entity_id)


async def _silence(hass: HomeAssistant, entity_ids: list[str]) -> None:
    """Stop playback on each speaker — both queue and in-flight announce.

    ``media_player.media_stop`` covers the queue (Sonos issues SOAP Stop
    via SoCo). Announces routed through ``announce: true`` ride a
    separate Sonos cloud-websocket channel (``audioClip:1``) that
    ignores volume/mute and survives a queue stop, so we also send
    ``cancelAudioClip`` to each speaker's websocket. Non-Sonos
    entities are skipped silently — the queue stop already handled
    them.
    """
    await hass.services.async_call(
        "media_player",
        "media_stop",
        {"entity_id": entity_ids},
        blocking=True,
    )
    for entity_id in entity_ids:
        await _cancel_audio_clip(hass, entity_id)


def _read_voice_effect(intent_output: dict | None) -> str | None:
    """Pull the voice_effect marker out of the INTENT_END event payload.

    An explicit ``card.voice_effect.title`` (set by intent_script via
    `lib.ha.voice.acknowledgeAction` / `silentAction`) always wins.
    Otherwise, error responses fall through to a code-driven mapping:

    * ``no_intent_match`` → ``silent`` — don't read the apology, just
      shrug. Sentence-level miss is usually because we mumbled or hit
      a sentence we never taught the matcher.
    * other error codes  → ``error`` — play the configured error
      chime in place of the TTS. Covers ``failed_to_handle``,
      ``no_valid_targets``, ``unknown`` — anything where the intent
      was recognised but went sideways on dispatch.

    Returns the effect name, or None when the response was a normal
    action-done and no explicit marker was set.
    """
    if not intent_output:
        return None
    response = intent_output.get("response") or {}
    card = response.get("card") or {}
    effect = card.get(VOICE_EFFECT_CARD_TYPE) or {}
    title = (effect.get("title") or "").strip().lower()
    if title:
        return title
    if response.get("response_type") == "error":
        code = (response.get("data") or {}).get("code") or ""
        if code == NO_MATCH_ERROR_CODE:
            return SILENT_EFFECT
        return ERROR_EFFECT
    return None


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    cfg = config.get(DOMAIN)
    if not cfg:
        return True

    routes = cfg.get(CONF_ROUTES) or []
    if not routes:
        return True

    sounds: dict[str, str] = cfg.get(CONF_SOUNDS) or {}

    by_satellite = {r[CONF_SATELLITE]: r for r in routes}

    # Per-satellite "last seen INTENT_END effect", consumed by the
    # immediately-following TTS_END. assist_satellite runs at most one
    # pipeline at a time per entity, so there's no concurrency risk.
    pending_effects: dict[str, str | None] = {}

    # Target media_players with an in-flight wake-word duck clip. We
    # cancel before any subsequent announce on the same target so the
    # TTS isn't queued behind the (15s) silence, and on pipeline
    # terminal events so a mid-pipeline abort doesn't strand the duck.
    active_ducks: set[str] = set()

    async def _clear_duck(target: str) -> None:
        if target in active_ducks:
            active_ducks.discard(target)
            await _cancel_audio_clip(hass, target)

    # Imported lazily so HA's manifest dependency resolution gets a
    # chance to load assist_satellite first.
    from homeassistant.components.assist_pipeline.pipeline import PipelineEventType
    from homeassistant.components.assist_satellite.entity import AssistSatelliteEntity

    original = AssistSatelliteEntity._internal_on_pipeline_event

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
            pending_effects[self.entity_id] = _read_voice_effect(intent_output)

        route = by_satellite.get(self.entity_id)
        if route is None:
            return
        target = route[CONF_TARGET]

        # Pipeline starting: fire the near-silent duck clip so the
        # target Sonos lowers its playback for the duration of the
        # interaction. Cancelled either on TTS_END (so the response
        # announce isn't queued behind it) or on RUN_END (defensive
        # cleanup for aborted pipelines). RUN_START rather than
        # WAKE_WORD_END because Wyoming satellites do their own wake
        # detection and start the HA pipeline at STT — HA never emits
        # WAKE_WORD_END for that path.
        if event.type == PipelineEventType.RUN_START:
            duck_path = sounds.get(DUCK_EFFECT)
            if not duck_path:
                return
            url = _absolutise(hass, duck_path)
            if not url:
                return
            active_ducks.add(target)
            hass.async_create_task(_announce(hass, route, url))
            return

        if event.type == PipelineEventType.RUN_END:
            hass.async_create_task(_clear_duck(target))
            return

        if event.type != PipelineEventType.TTS_END:
            return

        # Consume the marker the matching INTENT_END left behind. If
        # none, fall through to the default TTS-relay behaviour.
        effect = pending_effects.pop(self.entity_id, None)

        if effect == SILENT_EFFECT:
            _LOGGER.debug(
                "tts_relay: silent effect for %s; dropping TTS", self.entity_id
            )
            hass.async_create_task(_clear_duck(target))
            return

        async def _replace_duck_with(url: str) -> None:
            await _clear_duck(target)
            await _announce(hass, route, url)

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
                    hass.async_create_task(_replace_duck_with(url))
                    return

        tts_output = data.get("tts_output") or {}
        url = _absolutise(hass, tts_output.get("url"))
        if not url:
            hass.async_create_task(_clear_duck(target))
            return
        hass.async_create_task(_replace_duck_with(url))

    AssistSatelliteEntity._internal_on_pipeline_event = patched

    async def _handle_silence(call) -> None:
        entity_ids = call.data[ATTR_ENTITY_ID]
        if isinstance(entity_ids, str):
            entity_ids = [entity_ids]
        await _silence(hass, list(entity_ids))

    hass.services.async_register(
        DOMAIN,
        SERVICE_SILENCE,
        _handle_silence,
        schema=vol.Schema({vol.Required(ATTR_ENTITY_ID): cv.entity_ids}),
    )

    _LOGGER.info(
        "tts_relay: announcing TTS for %s; configured effects: %s",
        ", ".join(f"{k} -> {v[CONF_TARGET]}" for k, v in by_satellite.items()),
        sorted(sounds.keys()) or "(none)",
    )
    return True
