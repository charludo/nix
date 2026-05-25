{ config, ... }:
let
  e = config.hass.entities;
in
{
  hass.voice = {
    Ventilator_An = {
      sentences = [
        "(Schalte|Mach|Aktiviere) [den ]Ventilator [an|ein]"
        "Ventilator an"
      ];
      script = {
        action = [
          {
            action = "fan.turn_on";
            target.entity_id = e.fan.xiaomi_smart_fan;
          }
        ];
        speech.text = "Ventilator an.";
      };
    };

    Ventilator_Aus = {
      sentences = [
        "(Schalte|Mach|Deaktiviere) [den ]Ventilator (aus|ab)"
        "Ventilator aus"
      ];
      script = {
        action = [
          {
            action = "fan.turn_off";
            target.entity_id = e.fan.xiaomi_smart_fan;
          }
        ];
        speech.text = "Ventilator aus.";
      };
    };
  };
}
