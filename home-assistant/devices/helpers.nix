{ config, lib, ... }:
let
  a = lib.mapAttrs (_: v: v.name) config.hass.entities.area;
in
{
  hass.devices = {
    input_booleans = {
      settings_garten_anzucht = {
        name = "Garten: Anzucht";
        icon = "mdi:sprout";
        area = a.terrasse;
      };
      settings_garten_bewasserung = {
        name = "Garten: Bewässerung";
        icon = "mdi:water";
        area = a.terrasse;
      };
      settings_garten_heizung = {
        name = "Garten: Heizung";
        icon = "mdi:radiator";
        area = a.terrasse;
      };

      pumpe_uebersprungen = {
        name = "Pumpe übersprungen (Regen)";
        icon = "mdi:weather-rainy";
        area = a.terrasse;
      };

      turalarm = {
        name = "Türalarm";
        area = a.wohnzimmer;
      };
      turalarm_persistent = {
        name = "Türalarm (dauerhaft)";
        area = a.wohnzimmer;
      };

      botty_wohnzimmer_reinigen = {
        name = "Botty: Wohnzimmer reinigen";
        area = a.wohnzimmer;
      };
      botty_buro_reinigen = {
        name = "Botty: Büro reinigen";
        area = a.wohnzimmer;
      };
      botty_kueche_reinigen = {
        name = "Botty: Küche reinigen";
        area = a.wohnzimmer;
      };
      botty_sofa_reinigen = {
        name = "Botty: Sofa reinigen";
        area = a.wohnzimmer;
      };
    };

    input_numbers = {
      botty_wiederholungen = {
        name = "Botty: Wiederholungen";
        min = 1;
        max = 3;
        step = 1;
        initial = 1;
        area = a.wohnzimmer;
      };
      stunden_sonnenlicht_setzlinge = {
        name = "Sonnenlicht-Stunden (Setzlinge)";
        min = 1;
        max = 24;
        step = 1;
        initial = 14;
        area = a.terrasse;
      };
    };
  };
}
