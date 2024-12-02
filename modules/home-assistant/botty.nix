{ lib, config, ... }:
let
  cfg = config.hass.botty;
  e = config.hass.entities;

  zoneBool = slug: e.input_boolean.${"botty_${slug}_reinigen"};
  zoneToggles = lib.mapAttrsToList (slug: _: zoneBool slug) cfg.zones;

  vacuumCmd = data: {
    action = "vacuum.send_command";
    inherit data;
    target.entity_id = e.vacuum.botty;
  };

  zonedCleanParams =
    "["
    + lib.concatStrings (
      lib.mapAttrsToList (
        slug: z:
        "{% if is_state('${zoneBool slug}', 'on') %}[${
          lib.concatMapStringsSep "," toString [
            z.x1
            z.y1
            z.x2
            z.y2
          ]
        },{{ states.input_number.botty_wiederholungen.state | int }}],{% endif %}"
      ) cfg.zones
    )
    + "]";
in
{
  options.hass.botty = {
    zones = lib.mkOption {
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
      description = "Vacuum zone rectangles";
    };

    rooms = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [ ];
      description = "Room IDs";
    };
  };

  config.hass.scripts.botty_reinigung = lib.mkIf (cfg.zones != { }) {
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
          (vacuumCmd {
            command = "app_segment_clean";
            params = [ { segments = cfg.rooms; } ];
          })
        ];
        "else" = [
          (vacuumCmd {
            command = "app_zoned_clean";
            params = zonedCleanParams;
          })
        ];
      }
      {
        action = "input_boolean.turn_off";
        target.entity_id = zoneToggles;
      }
      {
        action = "input_number.set_value";
        data.value = 1;
        target.entity_id = e.input_number.botty_wiederholungen;
      }
    ];
  };
}
