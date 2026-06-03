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
          for = {
            hours = 0;
            minutes = 20;
            seconds = 0;
          };
        }
      ];
      action = [
        (notify e.persons.Charlotte.notify {
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
          for = {
            hours = 1;
            minutes = 0;
            seconds = 0;
          };
        }
      ];
      action = [
        (notify e.persons.Charlotte.notify {
          title = "Luftfeuchtigkeit im Badezimmer zu hoch";
          message = "Aufhören zu Duschen und Fenster aufmachen! 😡";
        })
        (notify e.persons.Marie.notify {
          title = "Luftfeuchtigkeit im Badezimmer zu hoch";
          message = "Aufhören zu Duschen und Fenster aufmachen! 😡";
        })
      ];
    };

    temperatur_serverschrank = {
      alias = "Temperatur Serverschrank Warnung";
      mode = "single";
      trigger = [
        {
          platform = "numeric_state";
          entity_id = e.sensor.thermometer_serverschrank.temperature;
          above = 40;
          for = {
            hours = 0;
            minutes = 5;
            seconds = 0;
          };
        }
      ];
      action = [
        (notify e.persons.Charlotte.notify {
          title = "Was da los?!";
          message = "Hohe Temperatur im Serverschrank";
        })
        (notify e.persons.Marie.notify {
          title = "Was da los?!";
          message = "Hohe Temperatur im Serverschrank";
        })
      ];
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
          for = {
            hours = 0;
            minutes = 4;
            seconds = 0;
          };
        }
      ];
      action = [
        (notify e.persons.Charlotte.notify {
          title = "Luftfeuchtigkeit im Wohnbereich zu hoch";
          message = "Zeit zu Lüften!";
        })
        (notify e.persons.Marie.notify {
          title = "Luftfeuchtigkeit im Wohnbereich zu hoch";
          message = "Zeit zu Lüften!";
        })
      ];
    };

    tursensor_alarm = {
      alias = "Türsensor Alarm";
      mode = "single";
      trigger = [
        {
          platform = "state";
          entity_id = e.binary_sensor.tursensor.opening;
          to = "on";
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
        (notify e.persons.Charlotte.notify {
          title = "Wohnungstür ist seit 3 Sekunden offen";
          message = "WOHNUNGSTÜR WURDE GEÖFFNET";
        })
        (notify e.persons.Marie.notify {
          title = "Wohnungstür ist seit 3 Sekunden offen";
          message = "WOHNUNGSTÜR WURDE GEÖFFNET";
        })
        {
          action = "input_boolean.turn_on";
          target.entity_id = e.input_boolean.turalarm_persistent;
        }
      ];
    };

    # Watches the min-battery group sensor (see helpers.nix) and pings
    # both phones with the names of all devices currently below 10%.
    # `expand` walks the group's members at firing time, so the list of
    # batteries stays driven by hass.devices.zigbee — no second source
    # of truth here.
    zigbee_low_battery = {
      alias = "Zigbee niedriger Akku";
      mode = "single";
      trigger = [
        {
          platform = "numeric_state";
          entity_id = e.sensor.zigbee_min_battery;
          below = lowBatteryThreshold;
          for = {
            hours = 0;
            minutes = 5;
            seconds = 0;
          };
        }
      ];
      action =
        let
          message = ''
            {% set ns = namespace(names=[]) %}
            {%- for s in expand('${e.sensor.zigbee_min_battery}') -%}
              {%- if s.state not in ['unknown', 'unavailable'] and (s.state | float(100)) < ${toString lowBatteryThreshold} -%}
                {%- set ns.names = ns.names + [s.name + ' (' + s.state + '%)'] -%}
              {%- endif -%}
            {%- endfor -%}
            Niedriger Akku: {{ ns.names | join(', ') }}
          '';
        in
        [
          (notify e.persons.Charlotte.notify {
            title = "Zigbee: Akku schwach";
            inherit message;
          })
          (notify e.persons.Marie.notify {
            title = "Zigbee: Akku schwach";
            inherit message;
          })
        ];
    };
  };
}
