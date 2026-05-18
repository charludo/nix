{ lib, config, ... }:
{
  options.hass.scripts = lib.mkOption {
    default = { };
    description = "Home Assistant scripts keyed by slug";
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        alias = lib.mkOption { type = lib.types.str; };
        description = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        icon = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        sequence = lib.mkOption {
          type = lib.types.listOf lib.types.anything;
          default = [ ];
        };
        mode = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
      };
    });
  };

  config.services.home-assistant.config.script = config.hass.scripts;
}
