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

  # For a room-specific intent: clear all toggles, set the requested
  # one, then start the cleaning script. This matches the spoken
  # semantic "clean ONLY this room", regardless of dashboard state.
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
    Botty_Start = [
      "(Starte|Beginne) [die ]Reinigung"
      "Reinigung starten"
      "Botty (los|reinigen|saugen|saug)"
      "Sauge"
    ];
    Botty_Ende = [
      "(Beende|Stoppe) [die ]Reinigung"
      "Reinigung (beenden|stoppen|fertig)"
      "Botty (zurück|nach Hause|zur Basis|fertig)"
    ];
    Botty_Wohnzimmer = [
      "(Reinige|Sauge) [im|das] Wohnzimmer"
      "Wohnzimmer (reinigen|saugen)"
    ];
    Botty_Buero = [
      "(Reinige|Sauge) [im|das] Büro"
      "Büro (reinigen|saugen)"
    ];
    Botty_Kueche = [
      "(Reinige|Sauge) [in der|die] Küche"
      "Küche (reinigen|saugen)"
    ];
    Botty_Sofa = [
      "(Reinige|Sauge) [vor|unter|am] [dem] Sofa"
      "Sofa (reinigen|saugen)"
    ];
  };

  hass.voice.intent_scripts = {
    Botty_Start = {
      action = [ { action = e.script.botty_reinigung; } ];
      speech.text = "Reinigung gestartet.";
    };
    Botty_Ende = {
      action = [ { action = e.script.botty_zurueckkehren; } ];
      speech.text = "Botty kehrt zurück.";
    };
    Botty_Wohnzimmer = {
      action = cleanRoom rooms.Wohnzimmer;
      speech.text = "Reinige Wohnzimmer.";
    };
    Botty_Buero = {
      action = cleanRoom rooms.Buero;
      speech.text = "Reinige Büro.";
    };
    Botty_Kueche = {
      action = cleanRoom rooms.Kueche;
      speech.text = "Reinige Küche.";
    };
    Botty_Sofa = {
      action = cleanRoom rooms.Sofa;
      speech.text = "Reinige Sofa.";
    };
  };
}
