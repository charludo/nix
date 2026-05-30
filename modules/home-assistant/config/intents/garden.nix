{ config, lib, ... }:
let
  e = config.hass.entities;
  ack = lib.ha.voice.acknowledgeAction;
in
{
  hass.voice.intents = {
    Pumpe_An = ack {
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

    Pumpe_Aus = ack {
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
