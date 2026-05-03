{ lib, config, ... }:
let
  cfg = config.hass;

  scriptSubmodule = {
    options = {
      alias = lib.mkOption {
        type = lib.types.str;
        description = "Human-readable name shown in the UI";
      };
      description = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional longer description of what the script does";
      };
      icon = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "MDI icon shown for the script";
      };
      sequence = lib.mkOption {
        type = lib.types.listOf lib.types.anything;
        default = [ ];
        description = "Sequence of actions the script executes";
      };
      mode = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Execution mode (single, restart, queued, parallel)";
      };
    };
  };
in
{
  imports = [
    ./botty.nix
    ./sonos.nix
  ];

  options.hass.scripts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule scriptSubmodule);
    default = { };
    description = "Home Assistant scripts keyed by slug";
  };

  config.services.home-assistant.config.script = cfg.scripts;
}
