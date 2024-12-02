{ config, ... }:
let
  e = config.hass.entities;
in
{
  hass.bewasserung.times = [
    "07:00"
    "10:00"
    {
      time = "13:00";
      degrees = 29;
    }
    {
      time = "16:00";
      degrees = 30;
    }
    "19:00"
  ];

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
          condition = "time";
          after = "19:00:00";
          before = "07:00:00";
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
          trigger = "template";
          id = "on";
          value_template = "{{ (as_timestamp(state_attr('${e.sun.sun}', 'next_dusk')) + 2 * 3600 - (states('${e.input_number.stunden_sonnenlicht_setzlinge}') | float(0) * 3600)) | timestamp_custom('%H:%M', true) == now().strftime('%H:%M') }}";
        }
        {
          trigger = "sun";
          id = "off";
          event = "sunset";
          offset = "02:00:00";
        }
      ];
      action = [
        {
          "if" = [
            {
              condition = "trigger";
              id = "on";
            }
          ];
          "then" = [
            {
              action = "switch.turn_on";
              target.entity_id = e.switch.steckdose_pflanzenlicht.switch;
            }
          ];
          "else" = [
            {
              action = "switch.turn_off";
              target.entity_id = e.switch.steckdose_pflanzenlicht.switch;
            }
          ];
        }
      ];
    };
  };
}
