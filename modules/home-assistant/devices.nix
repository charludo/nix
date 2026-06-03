{ lib, config, ... }:
let
  cfg = config.hass.devices;
in
{
  options.hass.devices = {
    zigbee = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            id = lib.mkOption {
              type = lib.types.str;
              description = "Zigbee IEEE address, colon-separated (e.g. 00:15:8d:00:09:45:19:da)";
            };
            area = lib.mkOption {
              type = lib.types.str;
              description = "HA area this device belongs to";
            };
            binary_sensor = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Binary-sensor sub-entity names";
            };
            diagnostic = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Diagnostic sub-entity names (battery, etc), emitted under the sensor domain";
            };
            light = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Light sub-entity names";
            };
            number = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Number sub-entity names";
            };
            select = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Select sub-entity names";
            };
            sensor = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Sensor sub-entity names";
            };
            switch = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Switch sub-entity names";
            };
          };
        }
      );
      default = { };
      description = "Zigbee devices managed by ZHA, keyed by human-readable name";
    };

    input_booleans = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Friendly name shown in the UI";
            };
            icon = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "MDI icon";
            };
            initial = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              default = null;
              description = "Initial state on Home Assistant startup";
            };
            area = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "HA area this entity belongs to";
            };
          };
        }
      );
      default = { };
      description = "Declarative input_boolean helpers keyed by slug";
    };

    input_numbers = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Friendly name shown in the UI";
            };
            min = lib.mkOption {
              type = lib.types.number;
              description = "Minimum allowed value";
            };
            max = lib.mkOption {
              type = lib.types.number;
              description = "Maximum allowed value";
            };
            step = lib.mkOption {
              type = lib.types.number;
              default = 1;
              description = "Slider step size";
            };
            initial = lib.mkOption {
              type = lib.types.nullOr lib.types.number;
              default = null;
              description = "Initial value on Home Assistant startup";
            };
            icon = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "MDI icon";
            };
            unit_of_measurement = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Unit shown next to the value";
            };
            area = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "HA area this entity belongs to";
            };
          };
        }
      );
      default = { };
      description = "Declarative input_number helpers keyed by slug";
    };
  }
  //
    lib.mapAttrs
      (
        _: description:
        lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options.area = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "HA area this entity belongs to";
              };
            }
          );
          default = { };
          inherit description;
        }
      )
      {
        media_players = "Known media_player entities keyed by slug";
        vacuums = "Known vacuum entities keyed by slug";
        fans = "Known fan entities keyed by slug";
        images = "Known image entities keyed by slug";
        suns = "Known sun entities keyed by slug";
        weathers = "Known weather entities keyed by slug";
        sensors = "Sensor entities (template, statistics, integration-provided) keyed by slug";
      };

  config.services.home-assistant.config = lib.mkMerge [
    (lib.mkIf (cfg.input_booleans != { }) {
      input_boolean = lib.mapAttrs (
        _: v: lib.filterAttrs (_: x: x != null) { inherit (v) name icon initial; }
      ) cfg.input_booleans;
    })
    (lib.mkIf (cfg.input_numbers != { }) {
      input_number = lib.mapAttrs (
        _: v:
        lib.filterAttrs (_: x: x != null) {
          inherit (v)
            name
            min
            max
            step
            initial
            icon
            unit_of_measurement
            ;
        }
      ) cfg.input_numbers;
    })
  ];
}
