{ lib, config, ... }:
{
  options.hass.automations = lib.mkOption {
    default = { };
    description = "Home Assistant automations keyed by slug";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          alias = lib.mkOption { type = lib.types.str; };
          description = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          trigger = lib.mkOption {
            type = lib.types.listOf lib.types.anything;
            default = [ ];
          };
          condition = lib.mkOption {
            type = lib.types.listOf lib.types.anything;
            default = [ ];
          };
          action = lib.mkOption {
            type = lib.types.listOf lib.types.anything;
            default = [ ];
          };
          mode = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
        };
      }
    );
  };

  config.services.home-assistant.config = lib.mkMerge (
    lib.mapAttrsToList (name: auto: { "automation ${name}" = auto; }) config.hass.automations
  );
}
