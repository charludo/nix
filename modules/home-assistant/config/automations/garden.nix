{ config, ... }:
let
  e = config.hass.entities;
in
{
  hass.automations = {
    heat_greenhouse = {
      alias = "Heat Greenhouse";
      mode = "single";
      trigger = [
        {
          platform = "numeric_state";
          entity_id = e.sensor.thermometer_gewachshaus.temperature;
          below = 5;
        }
      ];
      condition = [
        {
          condition = "and";
          conditions = [
            {
              condition = "time";
              after = "19:00:00";
              before = "07:00:00";
              weekday = [
                "mon"
                "tue"
                "wed"
                "thu"
                "fri"
                "sat"
                "sun"
              ];
            }
          ];
        }
      ];
      action = [
        {
          action = "switch.turn_on";
          target.entity_id = e.switch.steckdose_gewachshaus_heizung.switch;
        }
      ];
    };

    wasserpumpe_an = {
      alias = "Wasserpumpe an";
      mode = "single";
      trigger = [
        {
          at = "06:52:00";
          trigger = "time";
        }
        {
          at = "14:52:00";
          trigger = "time";
        }
        {
          at = "22:52:00";
          trigger = "time";
        }
      ];
      action = [
        {
          "if" = [
            {
              condition = "or";
              conditions = [
                {
                  condition = "numeric_state";
                  entity_id = e.sensor.cumulative_rain_8h;
                  above = 4;
                }
                {
                  condition = "numeric_state";
                  entity_id = e.sensor.cumulative_rain_24h;
                  above = 10;
                }
              ];
            }
          ];
          "then" = [
            {
              action = e.persons.Charlotte.notify;
              data.message = ''
                {% set r8 = states('${e.sensor.cumulative_rain_8h}') | float(0) %}
                {% if r8 > 4 %}
                  Pumpe nicht aktiviert: {{ '%.1f' | format(r8) }}mm Regen in den letzten 8h.
                {% else %}
                  Pumpe nicht aktiviert: {{ '%.1f' | format(states('${e.sensor.cumulative_rain_24h}') | float(0)) }}mm Regen in den letzten 24h.
                {% endif %}
              '';
            }
            {
              action = "input_boolean.turn_on";
              target.entity_id = e.input_boolean.pumpe_uebersprungen;
            }
          ];
          "else" = [
            {
              action = "switch.turn_on";
              target.entity_id = e.switch.steckdose_wasserpumpe.switch;
            }
            {
              "if" = [
                {
                  condition = "state";
                  entity_id = e.input_boolean.pumpe_uebersprungen;
                  state = "on";
                }
              ];
              "then" = [
                {
                  action = e.persons.Charlotte.notify;
                  data.message = "Pumpe reaktiviert.";
                }
                {
                  action = "input_boolean.turn_off";
                  target.entity_id = e.input_boolean.pumpe_uebersprungen;
                }
              ];
            }
          ];
        }
      ];
    };

    wasserpumpe_aus = {
      alias = "Wasserpumpe aus";
      mode = "single";
      trigger = [
        {
          at = "07:08:00";
          trigger = "time";
        }
        {
          at = "15:08:00";
          trigger = "time";
        }
        {
          at = "23:08:00";
          trigger = "time";
        }
      ];
      action = [
        {
          action = "switch.turn_off";
          target.entity_id = e.switch.steckdose_wasserpumpe.switch;
        }
      ];
    };

    pflanzenlicht_automatik = {
      alias = "Pflanzenlicht Automatik";
      mode = "single";
      trigger = [
        {
          value_template = "{{ (as_timestamp(state_attr('sun.sun', 'next_dusk')) + 2 * 3600 - (states('input_number.stunden_sonnenlicht_setzlinge') | float(0) * 3600)) | timestamp_custom('%H:%M', true) == now().strftime('%H:%M') }}";
          trigger = "template";
        }
        {
          event = "sunset";
          offset = "02:00:00";
          trigger = "sun";
        }
      ];
      action = [
        {
          choose = [
            {
              conditions = [
                {
                  condition = "template";
                  value_template = "{{ now().strftime('%H:%M') == (as_timestamp(state_attr('sun.sun', 'next_dusk')) + 2 * 3600 - (states('input_number.stunden_sonnenlicht_setzlinge') | float(0) * 3600)) | timestamp_custom('%H:%M', true) }}";
                }
              ];
              sequence = [
                {
                  action = "switch.turn_on";
                  data = { };
                  target.entity_id = e.switch.steckdose_pflanzenlicht.switch;
                }
              ];
            }
            {
              conditions = [
                {
                  condition = "sun";
                  after = "sunset";
                  after_offset = "02:00:00";
                }
              ];
              sequence = [
                {
                  action = "switch.turn_off";
                  data = { };
                  target.entity_id = e.switch.steckdose_pflanzenlicht.switch;
                }
              ];
            }
          ];
        }
      ];
    };
  };
}
