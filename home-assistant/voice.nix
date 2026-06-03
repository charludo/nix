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

  hass.voice.sounds = {
    acknowledge = ./assets/sounds/acknowledge-synth.mp3;
    timer = ./assets/sounds/timer-bell.mp3;
    reminder = ./assets/sounds/reminder-friendly.mp3;
    alarmclock = ./assets/sounds/wecker-chipper.mp3;
    error = ./assets/sounds/error-soft.mp3;
    duck = ./assets/sounds/silence.mp3;
  };

  hass.ttsRelay = [
    {
      satellite = "assist_satellite.hub_satellite";
      target = e.media_player.office;
      volume = 0.30;
    }
  ];
}
