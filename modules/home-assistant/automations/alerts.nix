{ lib, config, ... }:
let
  e = config.hass.entities;
in
{
  hass.automations = {
    warnung_temperatur_gewachshaus = {
      alias = "Warnung Temperatur Gewächshaus";
      mode = "single";
      trigger = [
        {
          type = "temperature";
          device_id = "70cb20071e81709dc7d1502ee3fbdb49";
          entity_id = "ad2c07998dbbaea707dbe4d760cad18c";
          domain = "sensor";
          below = 0;
          for = {
            hours = 0;
            minutes = 20;
            seconds = 0;
          };
          trigger = "device";
        }
      ];
      action = [
        {
          device_id = "516b50f7553924a7715b38915ae13d2e";
          domain = "mobile_app";
          type = "notify";
          title = "Temperaturwarnung";
          message = "Extremtemperatur im Gewächshaus";
        }
      ];
    };

    luftfeuchtigkeit_badezimmer = {
      alias = "Luftfeuchtigkeit Badezimmer";
      mode = "single";
      trigger = [
        {
          type = "humidity";
          device_id = "f284974c3950561470e1be47e62e20cb";
          entity_id = "ca842445976ae7d5c741cbe73a13e639";
          domain = "sensor";
          above = 90;
          for = {
            hours = 1;
            minutes = 0;
            seconds = 0;
          };
          trigger = "device";
        }
      ];
      action = [
        {
          device_id = "49089d6e5f2937900af87ddfa2c546d7";
          domain = "mobile_app";
          type = "notify";
          title = "Luftfeuchtigkeit im Badezimmer zu hoch";
          message = "Aufhören zu Duschen und Fenster aufmachen! 😡";
        }
        {
          device_id = "516b50f7553924a7715b38915ae13d2e";
          domain = "mobile_app";
          type = "notify";
          title = "Luftfeuchtigkeit im Badezimmer zu hoch";
          message = "Aufhören zu Duschen und Fenster aufmachen! 😡";
        }
      ];
    };

    temperatur_serverschrank = {
      alias = "Temperatur Serverschrank Warnung";
      mode = "single";
      trigger = [
        {
          type = "temperature";
          device_id = "294c2d42ad7b96830c9ec74764c98bb2";
          entity_id = "43b10957d7cc36298dfd304fe49badf5";
          domain = "sensor";
          above = 40;
          for = {
            hours = 0;
            minutes = 5;
            seconds = 0;
          };
          trigger = "device";
        }
      ];
      action = [
        {
          device_id = "49089d6e5f2937900af87ddfa2c546d7";
          domain = "mobile_app";
          type = "notify";
          title = "Was da los?!";
          message = "Hohe Temperatur im Serverschrank";
        }
        {
          device_id = "516b50f7553924a7715b38915ae13d2e";
          domain = "mobile_app";
          type = "notify";
          title = "Was da los?!";
          message = "Hohe Temperatur im Serverschrank";
        }
      ];
    };

    luftfeuchtigkeit_wohnbereich = {
      alias = "Luftfeuchtigkeit Wohnbereich";
      mode = "single";
      trigger = [
        {
          type = "humidity";
          device_id = "860ed7b7ab4e1efc439de46745bad67c";
          entity_id = "177f20364e2e44c0db0c8a252e920431";
          domain = "sensor";
          above = 65;
          for = {
            hours = 0;
            minutes = 4;
            seconds = 0;
          };
          trigger = "device";
        }
        {
          type = "humidity";
          device_id = "fac7206268dab0e6f8d2dbde9c617443";
          entity_id = "dbaf16566d1337ae15cad63bca90f62a";
          domain = "sensor";
          above = 65;
          for = {
            hours = 0;
            minutes = 4;
            seconds = 0;
          };
          trigger = "device";
        }
        {
          type = "humidity";
          device_id = "d2320ae9b6b409822d9e1080784faa40";
          entity_id = "df02b7fa469cba070a35bb4276a30180";
          domain = "sensor";
          above = 65;
          for = {
            hours = 0;
            minutes = 4;
            seconds = 0;
          };
          trigger = "device";
        }
      ];
      action = [
        {
          device_id = "49089d6e5f2937900af87ddfa2c546d7";
          domain = "mobile_app";
          type = "notify";
          title = "Luftfeuchtigkeit im Wohnbereich zu hoch";
          message = "Zeit zu Lüften!";
        }
        {
          device_id = "516b50f7553924a7715b38915ae13d2e";
          domain = "mobile_app";
          type = "notify";
          title = "Luftfeuchtigkeit im Wohnbereich zu hoch";
          message = "Zeit zu Lüften!";
        }
      ];
    };

    tursensor_alarm = {
      alias = "Türsensor Alarm";
      mode = "single";
      trigger = [
        {
          type = "opened";
          device_id = "0b93c90d37cef407277339168352bd68";
          entity_id = "020c530c49571e56076b4440d3e5e667";
          domain = "binary_sensor";
          trigger = "device";
          for = {
            hours = 0;
            minutes = 0;
            seconds = 3;
          };
        }
      ];
      condition = [
        {
          condition = "state";
          entity_id = e.input_boolean.turalarm;
          state = "on";
        }
      ];
      action = [
        {
          device_id = "49089d6e5f2937900af87ddfa2c546d7";
          domain = "mobile_app";
          type = "notify";
          title = "Wohnungstür ist seit 3 Sekunden offen";
          message = "WOHNUNGSTÜR WURDE GEÖFFNET";
        }
        {
          device_id = "5e726837dacfed345b3c0e30a6ab27d9";
          domain = "mobile_app";
          type = "notify";
          title = "Wohnungstür ist seit 3 Sekunden offen";
          message = "WOHNUNGSTÜR WURDE GEÖFFNET";
        }
        {
          device_id = "516b50f7553924a7715b38915ae13d2e";
          domain = "mobile_app";
          type = "notify";
          title = "Wohnungstür ist seit 3 Sekunden offen";
          message = "WOHNUNGSTÜR WURDE GEÖFFNET";
        }
        {
          action = "input_boolean.turn_on";
          metadata = { };
          data = { };
          target.entity_id = e.input_boolean.turalarm_persistent;
        }
      ];
    };
  };
}
