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
