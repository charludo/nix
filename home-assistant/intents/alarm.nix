{ config, ... }:
let
  e = config.hass.entities;
in
{
  hass.voice.intents.TueralarmAktivieren = {
    sentences = [
      "(Alarmanlage|Türalarm|Alarm) (aktivieren|scharfschalten|einschalten|anschalten)"
      "(Aktiviere|Schalte) [den |die ](Türalarm|Alarmanlage|Alarm) [scharf|ein|an]"
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
