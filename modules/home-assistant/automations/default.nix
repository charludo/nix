{ lib, config, ... }:
let
  cfg = config.hass;

  automationSubmodule = {
    options = {
      alias = lib.mkOption {
        type = lib.types.str;
        description = "Human-readable name shown in the UI";
      };
      description = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional longer description of what the automation does";
      };
      trigger = lib.mkOption {
        type = lib.types.listOf lib.types.anything;
        default = [ ];
        description = "List of triggers that fire the automation";
      };
      condition = lib.mkOption {
        type = lib.types.listOf lib.types.anything;
        default = [ ];
        description = "Conditions that must hold when a trigger fires";
      };
      action = lib.mkOption {
        type = lib.types.listOf lib.types.anything;
        default = [ ];
        description = "Sequence of actions executed when the automation runs";
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
    ./alerts.nix
    ./lights.nix
    ./garden.nix
    ./media.nix
  ];

  options.hass.automations = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule automationSubmodule);
    default = { };
    description = "Home Assistant automations keyed by slug";
  };

  config.services.home-assistant.config = lib.mkMerge (
    lib.mapAttrsToList (name: auto: {
      "automation ${name}" = auto;
    }) cfg.automations
  );
}
