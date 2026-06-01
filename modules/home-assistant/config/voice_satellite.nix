{ config, ... }:
let
  e = config.hass.entities;
in
{
  # Wyoming satellite (ReSpeaker mic array v2.0) has no speaker, so the
  # TTS leg of the assist pipeline has nowhere to land. ``tts_relay``
  # catches the pipeline's TTS_END event in-process and replays the
  # audio on the living-room Sonos with ``announce: true`` (ducks,
  # plays, restores).
  #
  # The satellite entity_id is whatever HA auto-discovered after
  # wyoming-satellite came online — check Settings → Devices &
  # services → Wyoming Protocol and adjust the string below if needed.
  hass.ttsRelay = [
    {
      satellite = "assist_satellite.hub_satellite";
      target = e.media_player.office;
      volume = 0.35;
    }
  ];

  # Sound files played by tts_relay in place of the TTS audio for
  # intents wrapped with lib.ha.voice.acknowledgeAction / silentAction
  # etc. Each path is symlinked individually under <configDir>/www/sounds/
  # (see voice.nix) and served from /local/sounds/<basename>. Set to
  # null to fall back to relaying the synthesized speech for that
  # category.
  hass.voice.sounds = {
    acknowledge = ./assets/sounds/acknowledge-synth.mp3;
    timer = ./assets/sounds/timer-bell.mp3;
    reminder = ./assets/sounds/reminder-friendly.mp3;
    alarmclock = ./assets/sounds/wecker-chipper.mp3;
    error = ./assets/sounds/error-kick.mp3;
    duck = ./assets/sounds/silence.mp3;
  };
}
