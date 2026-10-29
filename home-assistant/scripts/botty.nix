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
  # Re-doing the setup after a re-map (all values are in vacuum map space, mm):
  # - rooms: Developer Tools -> States -> image.botty_live_map, attribute
  #   `rooms`. Keys are the segment IDs for `rooms` below; x0/y0/x1/y1 are the
  #   room's bounding box and can be used as a whole-room zone. Names are not
  #   given, so identify a room by running app_segment_clean with that ID.
  # - zones: draw the rectangle in the map card/app and start the clean, with
  #   Developer Tools -> Events listening to `call_service`. The event's
  #   service_data.params is [[x1, y1, x2, y2, repeats]]. (Raw packet alternative:
  #   logger.set_level {miio: debug} and look for "app_zoned_clean" in the log.)
  hass.botty = {
    zones = {
      sofa = {
        x1 = 24601;
        y1 = 23474;
        x2 = 27927;
        y2 = 26098;
      };
      kueche = {
        x1 = 29859;
        y1 = 21837;
        x2 = 31409;
        y2 = 25715;
      };
      wohnzimmer = {
        x1 = 24800;
        y1 = 18350;
        x2 = 32950;
        y2 = 26000;
      };
      buro = {
        x1 = 24750;
        y1 = 16100;
        x2 = 28050;
        y2 = 19950;
      };
    };
    rooms = [
      2 # Wohnzimmer
      1 # Büro
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
