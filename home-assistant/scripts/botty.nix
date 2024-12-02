{ config, ... }:
let
  e = config.hass.entities;

  vacuumCmd = data: {
    action = "vacuum.send_command";
    inherit data;
    target.entity_id = e.vacuum.botty;
  };

  mkResetScript =
    { alias, consumable }:
    {
      inherit alias;
      sequence = [
        (vacuumCmd {
          command = "reset_consumable";
          params = [ consumable ];
        })
      ];
    };
in
{
  hass.botty = {
    zones = {
      sofa = {
        x1 = 23500;
        y1 = 25150;
        x2 = 26300;
        y2 = 29250;
      };
      kueche = {
        x1 = 19510;
        y1 = 25150;
        x2 = 23500;
        y2 = 27700;
      };
      wohnzimmer = {
        x1 = 19510;
        y1 = 25150;
        x2 = 26300;
        y2 = 31250;
      };
      buro = {
        x1 = 20250;
        y1 = 31300;
        x2 = 26250;
        y2 = 35100;
      };
    };
    rooms = [
      18 # Wohnzimmer
      17 # Büro
    ];
  };

  hass.scripts = {
    botty_wiederholungen = {
      alias = "Botty Wiederholungen";
      icon = "mdi:repeat";
      sequence = [
        {
          "if" = [
            {
              condition = "numeric_state";
              entity_id = e.input_number.botty_wiederholungen;
              below = 3;
            }
          ];
          "then" = [
            {
              action = "input_number.increment";
              target.entity_id = e.input_number.botty_wiederholungen;
            }
          ];
          "else" = [
            {
              action = "input_number.set_value";
              data.value = 1;
              target.entity_id = e.input_number.botty_wiederholungen;
            }
          ];
        }
      ];
    };

    botty_zurueckkehren = {
      alias = "Botty Zurückkehren";
      icon = "mdi:robot-vacuum";
      sequence = [
        (vacuumCmd { command = "app_pause"; })
        { delay.seconds = 2; }
        (vacuumCmd { command = "app_charge"; })
      ];
    };

    botty_pausieren = {
      alias = "Botty Pausieren";
      icon = "mdi:robot-vacuum";
      sequence = [ (vacuumCmd { command = "app_pause"; }) ];
    };

    botty_fortsetzen = {
      alias = "Botty Fortsetzen";
      icon = "mdi:robot-vacuum";
      sequence = [ (vacuumCmd { command = "resume_zoned_clean"; }) ];
    };

    botty_main_brush_reset = mkResetScript {
      alias = "Botty main brush reset";
      consumable = "main_brush_work_time";
    };

    botty_side_brush_reset = mkResetScript {
      alias = "Botty side brush reset";
      consumable = "side_brush_work_time";
    };

    botty_filter_reset = mkResetScript {
      alias = "Botty filter reset";
      consumable = "filter_work_time";
    };

    botty_sensor_cleaning_reset = mkResetScript {
      alias = "Botty sensor cleaning reset";
      consumable = "sensor_dirty_time";
    };
  };
}
