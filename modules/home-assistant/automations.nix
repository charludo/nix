{ lib, config, ... }:
let
  cfg = config.hass.automations;
in
{
  options.hass.automations = lib.mkOption {
    default = { };
    description = "Home Assistant automations keyed by slug";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          alias = lib.mkOption {
            type = lib.types.str;
            description = "Human-readable name shown in the UI";
          };
          description = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Longer description of what the automation does";
          };
          trigger = lib.mkOption {
            type = lib.types.listOf lib.types.anything;
            default = [ ];
            description = "Triggers that fire the automation";
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
          variables = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
            description = "Variables in scope for the trigger and action sequence";
          };
        };
      }
    );
  };

  config.services.home-assistant.config = lib.mkMerge (
    lib.mapAttrsToList (name: auto: {
      "automation ${name}" = auto // {
        id = name;
      };
    }) cfg
  );
}
