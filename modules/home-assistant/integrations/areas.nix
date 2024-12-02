{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hass;
  mkSlug = lib.ha.mkSlug;

  areaSubmodule = lib.types.submodule {
    options = {
      order = lib.mkOption {
        type = lib.types.int;
        default = 1000;
        description = "Sort order for sidebar and dashboard tabs (lower = first).";
      };
      icon = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "MDI icon string, e.g. mdi:door";
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
  };

  sortedAreas = lib.sort (a: b: a.value.order < b.value.order) (
    lib.mapAttrsToList lib.nameValuePair cfg.areas
  );

  mkAreaEntry = name: area: {
    id = mkSlug name;
    inherit name;
    icon = area.icon;
    humidity_entity_id = area.humidityEntity;
    temperature_entity_id = area.temperatureEntity;
    aliases = [ ];
    floor_id = null;
    labels = [ ];
    picture = null;
    created_at = "1970-01-01T00:00:00+00:00";
    modified_at = "1970-01-01T00:00:00+00:00";
  };

  registryFile = pkgs.writeText "core.area_registry" (
    builtins.toJSON {
      version = 1;
      minor_version = 8;
      key = "core.area_registry";
      data.areas = map (nv: mkAreaEntry nv.name nv.value) sortedAreas;
    }
  );
in
{
  options.hass.areas = lib.mkOption {
    type = lib.types.attrsOf areaSubmodule;
    default = { };
    description = "Home Assistant areas, written declaratively to .storage/core.area_registry.";
  };

  config = lib.mkIf (cfg.areas != { }) {
    systemd.tmpfiles.rules = [
      "L+ ${config.services.home-assistant.configDir}/.storage/core.area_registry - - - - ${registryFile}"
    ];
  };
}
