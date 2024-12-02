{ config, ... }:
let
  e = config.hass.entities;
in
{
  hass.voice.defaultLanguage = "de";
  hass.voice.extraConfig.de.skip_words = [ ];
  hass.voice.disableBuiltinIntents = [
    "HassGetWeather"
    "HassClimateGetTemperature"
    "HassVacuumStart"
    "HassTurnOn"
    "HassTurnOff"
    "HassGetState"
  ];

  # Tighten assist_pipeline's end-of-speech detection. Upstream defaults
  # (0.7s silence / 15s timeout) make the satellite feel sluggish to
  # respond and prone to picking up unrelated noise during the long tail.
  hass.voice.vad.silenceSeconds = 0.4;
  hass.voice.vad.timeoutSeconds = 6.0;

  hass.voice.sounds = {
    acknowledge = ./assets/sounds/acknowledge-synth.mp3;
    timer = ./assets/sounds/timer-chimes.mp3;
    reminder = ./assets/sounds/reminder-friendly.mp3;
    alarmclock = ./assets/sounds/wecker-chipper.mp3;
    error = ./assets/sounds/error-soft.mp3;
    duck = ./assets/sounds/silence.mp3;
  };

  hass.ttsRelay = [
    {
      satellite = "satellite-wohnzimmer";
      target = e.media_player.living_room;
      volume = 0.30;
    }
  ];
}
