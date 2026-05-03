{ lib, config, ... }:
let
  e = config.hass.entities;
  cfg = config.hass.botty;

  zoneToggles = lib.mapAttrsToList (slug: _: e.input_boolean.${"botty_${slug}_reinigen"}) cfg.zones;

  # One Jinja {% if %}-clause per zone; emits its rectangle plus the global
  # repeat counter only when the matching toggle is on.
  mkZoneClause =
    slug:
    {
      x1,
      y1,
      x2,
      y2,
    }:
    let
      bool = e.input_boolean.${"botty_${slug}_reinigen"};
      coords = lib.concatStringsSep "," (
        map toString [
          x1
          y1
          x2
          y2
        ]
      );
    in
    "{% if is_state('${bool}', 'on') %}[${coords},{{ states.input_number.botty_wiederholungen.state | int }}],{% endif %}";

  zonedCleanParams = "[" + lib.concatStrings (lib.mapAttrsToList mkZoneClause cfg.zones) + "]";
in
{
  options.hass.botty.zones = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          x1 = lib.mkOption {
            type = lib.types.int;
            description = "First-corner X coordinate (vacuum map space)";
          };
          y1 = lib.mkOption {
            type = lib.types.int;
            description = "First-corner Y coordinate (vacuum map space)";
          };
          x2 = lib.mkOption {
            type = lib.types.int;
            description = "Opposite-corner X coordinate";
          };
          y2 = lib.mkOption {
            type = lib.types.int;
            description = "Opposite-corner Y coordinate";
          };
        };
      }
    );
    default = { };
    description = "Vacuum zone rectangles keyed by room slug; each is paired with input_boolean.botty_<slug>_reinigen";
  };

  config.hass.scripts = {
    botty_reinigung = {
      alias = "Botty Reinigung";
      icon = "mdi:robot-vacuum";
      sequence = [
        {
          "if" = [
            {
              condition = "and";
              conditions = map (entity_id: {
                condition = "state";
                inherit entity_id;
                state = "off";
              }) zoneToggles;
            }
          ];
          "then" = [
            {
              action = "vacuum.send_command";
              data = {
                command = "app_segment_clean";
                params = [
                  {
                    segments = [
                      16
                      17
                    ];
                  }
                ];
              };
              target.entity_id = e.vacuum.botty;
            }
          ];
          "else" = [
            {
              action = "vacuum.send_command";
              data = {
                command = "app_zoned_clean";
                params = zonedCleanParams;
              };
              target.entity_id = e.vacuum.botty;
            }
          ];
        }
        {
          action = "input_boolean.turn_off";
          data = { };
          target.entity_id = zoneToggles;
        }
        {
          action = "input_number.set_value";
          data.value = 1;
          target.entity_id = e.input_number.botty_wiederholungen;
        }
      ];
    };

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
              data = { };
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
        {
          action = "vacuum.send_command";
          data.command = "app_pause";
          target.entity_id = e.vacuum.botty;
        }
        {
          delay = {
            hours = 0;
            minutes = 0;
            seconds = 2;
            milliseconds = 0;
          };
        }
        {
          action = "vacuum.send_command";
          data.command = "app_charge";
          target.entity_id = e.vacuum.botty;
        }
      ];
    };

    botty_pausieren = {
      alias = "Botty Pausieren";
      icon = "mdi:robot-vacuum";
      sequence = [
        {
          action = "vacuum.send_command";
          data.command = "app_pause";
          target.entity_id = e.vacuum.botty;
        }
      ];
    };

    botty_fortsetzen = {
      alias = "Botty Fortsetzen";
      icon = "mdi:robot-vacuum";
      sequence = [
        {
          action = "vacuum.send_command";
          data.command = "resume_zoned_clean";
          target.entity_id = e.vacuum.botty;
        }
      ];
    };

    botty_main_brush_reset = {
      alias = "Botty main brush reset";
      sequence = [
        {
          action = "vacuum.send_command";
          target.entity_id = e.vacuum.botty;
          data = {
            command = "reset_consumable";
            params = [ "main_brush_work_time" ];
          };
        }
      ];
    };

    botty_side_brush_reset = {
      alias = "Botty side brush reset";
      sequence = [
        {
          action = "vacuum.send_command";
          target.entity_id = e.vacuum.botty;
          data = {
            command = "reset_consumable";
            params = [ "side_brush_work_time" ];
          };
        }
      ];
    };

    botty_filter_reset = {
      alias = "Botty filter reset";
      sequence = [
        {
          action = "vacuum.send_command";
          target.entity_id = e.vacuum.botty;
          data = {
            command = "reset_consumable";
            params = [ "filter_work_time" ];
          };
        }
      ];
    };

    botty_sensor_cleaning_reset = {
      alias = "Botty sensor cleaning reset";
      sequence = [
        {
          action = "vacuum.send_command";
          target.entity_id = e.vacuum.botty;
          data = {
            command = "reset_consumable";
            params = [ "sensor_dirty_time" ];
          };
        }
      ];
    };
  };
}
