{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hass;

  registryFile = pkgs.writeText "core.area_registry" (
    builtins.toJSON {
      version = 1;
      minor_version = 8;
      key = "core.area_registry";
      data.areas =
        map
          (nv: {
            id = lib.ha.mkSlug nv.name;
            name = nv.name;
            icon = nv.value.icon;
            humidity_entity_id = nv.value.humidityEntity;
            temperature_entity_id = nv.value.temperatureEntity;
            aliases = [ ];
            floor_id = null;
            labels = [ ];
            picture = null;
            created_at = "1970-01-01T00:00:00+00:00";
            modified_at = "1970-01-01T00:00:00+00:00";
          })
          (lib.sort (a: b: a.value.order < b.value.order) (lib.mapAttrsToList lib.nameValuePair cfg.areas));
    }
  );
in
{
  options.hass.areas = lib.mkOption {
    default = { };
    description = "Home Assistant areas, written declaratively to .storage/core.area_registry";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          order = lib.mkOption {
            type = lib.types.int;
            default = 1000;
            description = "Sort order for sidebar and dashboard tabs (lower = first)";
          };
          icon = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "MDI icon for the area";
          };
          humidityEntity = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Entity ID for the area's humidity sensor";
          };
          temperatureEntity = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Entity ID for the area's temperature sensor";
          };
        };
      }
    );
  };

  config = lib.mkIf (cfg.areas != { }) {
    systemd.tmpfiles.rules = [
      "L+ ${config.services.home-assistant.configDir}/.storage/core.area_registry - - - - ${registryFile}"
    ];
  };
}
