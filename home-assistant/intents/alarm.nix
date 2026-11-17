{ config, ... }:
let
  e = config.hass.entities;
in
{
  hass.voice.intents.TueralarmAktivieren = {
    sentences = [
      "(Alarmanlage|Türalarm|Alarm) (aktivieren|scharfschalten|einschalten|anschalten)"
      # Split: closest_intent expands a pattern into at most 16 forms.
      "Aktiviere [den |die ]Türalarm [scharf|ein|an]"
      "Aktiviere [den |die ]Alarmanlage [scharf|ein|an]"
      "Aktiviere [den |die ]Alarm [scharf|ein|an]"
      "Schalte [den |die ]Türalarm [scharf|ein|an]"
      "Schalte [den |die ]Alarmanlage [scharf|ein|an]"
      "Schalte [den |die ]Alarm [scharf|ein|an]"
      "Sicherheitsmodus"
    ];
    script = {
      async_action = true;
      action = [
        { delay.minutes = 1; }
        {
          action = "input_boolean.turn_on";
          target.entity_id = e.input_boolean.turalarm;
        }
      ];
      speech.text = "Türalarm wird in einer Minute aktiviert.";
    };
  };
}
