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
  hass.voice = {
    Botty_Start = {
      sentences = [
        "(Starte|Beginne) [die ]Reinigung"
        "Reinigung starten"
        "Botty (starten|los|reinigen|saugen|saug)"
        "Sauge"
      ];
      script = {
        action = [ { action = e.script.botty_reinigung; } ];
        speech.text = "Reinigung gestartet.";
      };
    };

    Botty_Ende = {
      sentences = [
        "(Beende|Stoppe) [die ]Reinigung"
        "Reinigung (beenden|stoppen)"
        "Botty (zurück|nach Hause|zur Basis|stop)"
      ];
      script = {
        action = [ { action = e.script.botty_zurueckkehren; } ];
        speech.text = "Reinigung beendet.";
      };
    };

    Botty_Wohnzimmer = {
      sentences = [
        "(Reinige|Sauge) [im|das] Wohnzimmer"
        "Botty [ins] Wohnzimmer"
        "Wohnzimmer (reinigen|saugen)"
      ];
      script = {
        action = cleanRoom rooms.Wohnzimmer;
        speech.text = "Reinige Wohnzimmer.";
      };
    };

    Botty_Buero = {
      sentences = [
        "(Reinige|Sauge) [im|das] (Büro|Arbeitszimmer)"
        "Botty [ins] (Büro|Arbeitszimmer)"
        "(Büro|Arbeitszimmer) (reinigen|saugen)"
      ];
      script = {
        action = cleanRoom rooms.Buero;
        speech.text = "Reinige Büro.";
      };
    };

    Botty_Kueche = {
      sentences = [
        "(Reinige|Sauge) [in der|die] Küche"
        "Botty [in die] Küche"
        "[Botty] Küche (reinigen|saugen)"
      ];
      script = {
        action = cleanRoom rooms.Kueche;
        speech.text = "Reinige Küche.";
      };
    };

    Botty_Sofa = {
      sentences = [
        "(Reinige|Sauge) [vor|unter|am] [dem] [Fernseher|Sofa]"
        "[Botty] [vorm|vor dem] (Sofa|Fernseher) (reinigen|saugen)"
      ];
      script = {
        action = cleanRoom rooms.Sofa;
        speech.text = "Reinige Sofa.";
      };
    };
  };
}
