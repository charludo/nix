{ lib, config, ... }:
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

    deaktiviere_pumpe_nach_regen = {
      alias = "Deaktiviere Pumpe nach Regen";
      mode = "single";
      trigger = [
        {
          at = "06:30:00";
          trigger = "time";
        }
        {
          at = "14:30:00";
          trigger = "time";
        }
        {
          at = "22:30:00";
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
              condition = "state";
              entity_id = e.switch.steckdose_wasserpumpe.switch;
              state = "on";
            }
            {
              action = "switch.turn_off";
              target.entity_id = e.switch.steckdose_wasserpumpe.switch;
            }
            {
              action = e.mobile_app.phone_charlotte;
              data.message = "Disabled pump due to rain in the past 16 hours.";
            }
          ];
          "else" = [
            {
              condition = "state";
              entity_id = e.switch.steckdose_wasserpumpe.switch;
              state = "off";
            }
            {
              action = "switch.turn_on";
              target.entity_id = e.switch.steckdose_wasserpumpe.switch;
            }
            {
              action = e.mobile_app.phone_charlotte;
              data.message = "Re-activated pump.";
            }
          ];
        }
      ];
    };

    pflanzenlicht = {
      alias = "Pflanzenlicht an/aus";
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
