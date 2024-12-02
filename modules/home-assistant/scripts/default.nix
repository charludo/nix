{ lib, config, ... }:
let
  cfg = config.hass;

  scriptSubmodule = {
    options = {
      alias = lib.mkOption {
        type = lib.types.str;
      };
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
  };
in
{
  imports = [
    ./botty.nix
    ./sonos.nix
    ./tv.nix
  ];

  options.hass.scripts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule scriptSubmodule);
    default = { };
  };

  config.services.home-assistant.config.script = cfg.scripts;
}
