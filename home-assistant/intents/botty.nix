{ lib, config, ... }:
let
  e = config.hass.entities;

  rooms = {
    Wohnzimmer = e.input_boolean.botty_wohnzimmer_reinigen;
    Buero = e.input_boolean.botty_buro_reinigen;
    Kueche = e.input_boolean.botty_kueche_reinigen;
    Sofa = e.input_boolean.botty_sofa_reinigen;
  };

  allRoomBools = lib.attrValues rooms;

  cleanRoom = roomBool: [
    {
      action = "input_boolean.turn_off";
      target.entity_id = allRoomBools;
    }
    {
      action = "input_boolean.turn_on";
      target.entity_id = roomBool;
    }
    { action = e.script.botty_reinigung; }
  ];
in
{
  hass.voice.intents = {
    BottyStart = {
      sentences = [
        "(Starte|Beginne) [die |den ]Reinigung[svorgang]"
        "(Reinigung[svorgang]|Botty) starten"
      ];
      script = {
        action = [ { action = e.script.botty_reinigung; } ];
        speech.text = "Starte Reinigung.";
      };
    };

    BottyEnde = {
      sentences = [
        "(Beende|Stoppe) [die |den ]Reinigung[svorgang]"
        "(Reinigung[svorgang]|Botty) (beenden|stoppen)"
        "Botty ([zurück ]nach Hause|zur Basis|stoppen|anhalten)"
      ];
      script = {
        action = [ { action = e.script.botty_zurueckkehren; } ];
        speech.text = "Reinigung beendet.";
      };
    };

    BottyWohnzimmer = {
      sentences = [
        "(Reinige|Sauge|Botty) [im|das|ins] Wohnzimmer"
        "[Botty] Wohnzimmer (reinigen|saugen)"
      ];
      script = {
        action = cleanRoom rooms.Wohnzimmer;
        speech.text = "Reinige Wohnzimmer.";
      };
    };

    BottyBuero = {
      sentences = [
        "(Reinige|Sauge|Botty) [im|das|ins] (Büro|Arbeitszimmer)"
        "[Botty] (Büro|Arbeitszimmer) (reinigen|saugen)"
      ];
      script = {
        action = cleanRoom rooms.Buero;
        speech.text = "Reinige Büro.";
      };
    };

    BottyKueche = {
      sentences = [
        "(Reinige|Sauge|Botty) [in der|in die|die] Küche"
        "[Botty] Küche (reinigen|saugen)"
      ];
      script = {
        action = cleanRoom rooms.Kueche;
        speech.text = "Reinige Küche.";
      };
    };

    BottySofa = {
      sentences = [
        "(Reinige|Sauge|Botty) [vor|unter|am] [dem] (Fernseher|Sofa)"
        "[Botty] [vorm|vor dem] (Sofa|Fernseher) (reinigen|saugen)"
      ];
      script = {
        action = cleanRoom rooms.Sofa;
        speech.text = "Reinige Sofa.";
      };
    };
  };
}
