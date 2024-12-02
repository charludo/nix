{ ... }:
{
  hass.automations = {
    licht_an_bei_toilettengang = {
      alias = "Licht an bei Toilettengang";
      mode = "single";
      trigger = [
        {
          type = "motion";
          platform = "device";
          device_id = "d2bab798acadc41473cab603251f3bab";
          entity_id = "1a1b4452116eabcb90717ffdb41dd6b3";
          domain = "binary_sensor";
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
              condition = "device";
              type = "is_off";
              device_id = "7c9fa7b2158e8bb87759b9ce6a97560a";
              entity_id = "f4686c2712b4575c9022ef7d646425b4";
              domain = "light";
            }
          ];
        }
      ];
      action = [
        {
          type = "turn_on";
          device_id = "7c9fa7b2158e8bb87759b9ce6a97560a";
          entity_id = "f4686c2712b4575c9022ef7d646425b4";
          domain = "light";
          brightness_pct = 100;
        }
      ];
    };

    licht_aus_nach_toilettengang = {
      alias = "Licht aus nach Toilettengang";
      mode = "single";
      trigger = [
        {
          type = "motion";
          platform = "device";
          device_id = "d2bab798acadc41473cab603251f3bab";
          entity_id = "1a1b4452116eabcb90717ffdb41dd6b3";
          domain = "binary_sensor";
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
              condition = "device";
              type = "is_on";
              device_id = "7c9fa7b2158e8bb87759b9ce6a97560a";
              entity_id = "f4686c2712b4575c9022ef7d646425b4";
              domain = "light";
            }
          ];
        }
      ];
      action = [
        {
          type = "turn_off";
          device_id = "7c9fa7b2158e8bb87759b9ce6a97560a";
          entity_id = "f4686c2712b4575c9022ef7d646425b4";
          domain = "light";
        }
      ];
    };
  };
}
