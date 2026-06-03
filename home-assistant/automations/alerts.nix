{ config, lib, ... }:
let
  e = config.hass.entities;
  inherit (lib.ha) lowBatteryThreshold;

  notify =
    target:
    {
      title,
      message,
    }:
    {
      action = target;
      data = { inherit title message; };
    };

  notifyBoth = msg: [
    (notify e.person.charlotte.notify msg)
    (notify e.person.marie.notify msg)
  ];
in
{
  hass.automations = {
    warnung_temperatur_gewachshaus = {
      alias = "Warnung Temperatur Gewächshaus";
      mode = "single";
      trigger = [
        {
          platform = "numeric_state";
          entity_id = e.sensor.thermometer_gewachshaus.temperature;
          below = 0;
          for.minutes = 20;
        }
      ];
      action = [
        (notify e.person.charlotte.notify {
          title = "Temperaturwarnung";
          message = "Extremtemperatur im Gewächshaus";
        })
      ];
    };

    luftfeuchtigkeit_badezimmer = {
      alias = "Luftfeuchtigkeit Badezimmer";
      mode = "single";
      trigger = [
        {
          platform = "numeric_state";
          entity_id = e.sensor.thermometer_badezimmer.humidity;
          above = 90;
          for.hours = 1;
        }
      ];
      action = notifyBoth {
        title = "Luftfeuchtigkeit im Badezimmer zu hoch";
        message = "Aufhören zu Duschen und Fenster aufmachen! 😡";
      };
    };

    temperatur_serverschrank = {
      alias = "Temperatur Serverschrank Warnung";
      mode = "single";
      trigger = [
        {
          platform = "numeric_state";
          entity_id = e.sensor.thermometer_serverschrank.temperature;
          above = 40;
          for.minutes = 5;
        }
      ];
      action = notifyBoth {
        title = "Was da los?!";
        message = "Hohe Temperatur im Serverschrank";
      };
    };

    luftfeuchtigkeit_wohnbereich = {
      alias = "Luftfeuchtigkeit Wohnbereich";
      mode = "single";
      trigger = [
        {
          platform = "numeric_state";
          entity_id = [
            e.sensor.thermometer_wohnzimmer.humidity
            e.sensor.thermometer_schlafzimmer.humidity
            e.sensor.thermometer_buro.humidity
          ];
          above = 65;
          for.minutes = 4;
        }
      ];
      action = notifyBoth {
        title = "Luftfeuchtigkeit im Wohnbereich zu hoch";
        message = "Zeit zu Lüften!";
      };
    };

    tursensor_alarm = {
      alias = "Türsensor Alarm";
      mode = "single";
      trigger = [
        {
          platform = "state";
          entity_id = e.binary_sensor.tursensor.opening;
          to = "on";
          for.seconds = 3;
        }
      ];
      condition = [
        {
          condition = "state";
          entity_id = e.input_boolean.turalarm;
          state = "on";
        }
      ];
      action =
        notifyBoth {
          title = "Wohnungstür ist seit 3 Sekunden offen";
          message = "WOHNUNGSTÜR WURDE GEÖFFNET";
        }
        ++ [
          {
            action = "input_boolean.turn_on";
            target.entity_id = e.input_boolean.turalarm_persistent;
          }
        ];
    };

    zigbee_low_battery = {
      alias = "Zigbee niedriger Akku";
      mode = "single";
      trigger = [
        {
          platform = "numeric_state";
          entity_id = e.sensor.zigbee_min_battery;
          below = lowBatteryThreshold;
          for.minutes = 5;
        }
      ];
      action = notifyBoth {
        title = "Zigbee: Akku schwach";
        message = ''
          {% set ns = namespace(names=[]) %}
          {%- for s in expand('${e.sensor.zigbee_min_battery}') -%}
            {%- if s.state not in ['unknown', 'unavailable'] and (s.state | float(100)) < ${toString lowBatteryThreshold} -%}
              {%- set ns.names = ns.names + [s.name + ' (' + s.state + '%)'] -%}
            {%- endif -%}
          {%- endfor -%}
          Niedriger Akku: {{ ns.names | join(', ') }}
        '';
      };
    };
  };
}
