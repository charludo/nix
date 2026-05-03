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
          type = "temperature";
          platform = "device";
          device_id = "0d0c12739a631dc265cac89ddf746d79";
          entity_id = "2ef90068ad11bc1ce32e743ea56479e5";
          domain = "sensor";
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
          type = "turn_on";
          device_id = "eb3007b41930c5b917d219ee918f1d27";
          entity_id = "f8c2c05a274826ae13fd387acb8782ee";
          domain = "switch";
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
              metadata = { };
              data = { };
              target.device_id = "7a7069710c1960c35f7ccc83c00a424e";
              action = "switch.turn_off";
            }
            {
              action = "notify.mobile_app_xiaomi_15";
              metadata = { };
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
              metadata = { };
              data = { };
              target.device_id = "7a7069710c1960c35f7ccc83c00a424e";
              action = "switch.turn_on";
            }
            {
              action = "notify.mobile_app_xiaomi_15";
              metadata = { };
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
