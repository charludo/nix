{ lib, ... }:
{
  options.hass.devices.zigbee = lib.mkOption {
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
}
