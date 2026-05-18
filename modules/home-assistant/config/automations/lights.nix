{ config, ... }:
let
  e = config.hass.entities;
in
{
  hass.automations = {
    licht_an_bei_toilettengang = {
      alias = "Licht an bei Toilettengang";
      mode = "single";
      trigger = [
        {
          platform = "state";
          entity_id = e.binary_sensor.bewegungsmelder.motion;
          to = "on";
        }
      ];
      condition = [
        {
          condition = "and";
          conditions = [
            {
              condition = "time";
              after = "23:00:00";
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
            {
              condition = "state";
              entity_id = e.light.strahler.light;
              state = "off";
            }
          ];
        }
      ];
      action = [
        {
          action = "light.turn_on";
          target.entity_id = e.light.strahler.light;
          data.brightness_pct = 100;
        }
      ];
    };

    licht_aus_nach_toilettengang = {
      alias = "Licht aus nach Toilettengang";
      mode = "single";
      trigger = [
        {
          platform = "state";
          entity_id = e.binary_sensor.bewegungsmelder.motion;
          to = "off";
        }
      ];
      condition = [
        {
          condition = "and";
          conditions = [
            {
              condition = "time";
              after = "23:00:00";
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
            {
              condition = "state";
              entity_id = e.light.strahler.light;
              state = "on";
            }
          ];
        }
      ];
      action = [
        {
          action = "light.turn_off";
          target.entity_id = e.light.strahler.light;
        }
      ];
    };
  };
}
