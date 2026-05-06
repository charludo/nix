{ config, ... }:
let
  e = config.hass.entities;
in
{
  hass.voice.intents = {
    PumpeAn = [
      "(Aktiviere|Schalte) [die ][Wasser]Pumpe [an|ein]"
      "[Wasser]Pumpe an"
    ];
    PumpeAus = [
      "(Deaktiviere|Schalte) [die ][Wasser]Pumpe (aus|ab)"
      "[Wasser]Pumpe aus"
    ];
  };

  hass.voice.intent_scripts = {
    PumpeAn = {
      action = [
        {
          action = "switch.turn_on";
          target.entity_id = e.switch.steckdose_wasserpumpe.switch;
        }
      ];
      speech.text = "Wasserpumpe aktiviert.";
    };
    PumpeAus = {
      action = [
        {
          action = "switch.turn_off";
          target.entity_id = e.switch.steckdose_wasserpumpe.switch;
        }
      ];
      speech.text = "Wasserpumpe deaktiviert.";
    };
  };
}
