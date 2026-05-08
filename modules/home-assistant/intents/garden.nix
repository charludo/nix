{ config, ... }:
let
  e = config.hass.entities;
in
{
  hass.voice = {
    Pumpe_An = {
      sentences = [
        "(Aktiviere|Schalte) [die ][Wasser]Pumpe [an|ein]"
        "[Wasser]Pumpe an"
      ];
      script = {
        action = [
          {
            action = "switch.turn_on";
            target.entity_id = e.switch.steckdose_wasserpumpe.switch;
          }
        ];
        speech.text = "Wasserpumpe aktiviert.";
      };
    };

    Pumpe_Aus = {
      sentences = [
        "(Deaktiviere|Schalte) [die ][Wasser]Pumpe (aus|ab)"
        "[Wasser]Pumpe aus"
      ];
      script = {
        action = [
          {
            action = "switch.turn_off";
            target.entity_id = e.switch.steckdose_wasserpumpe.switch;
          }
        ];
        speech.text = "Wasserpumpe deaktiviert.";
      };
    };
  };
}
