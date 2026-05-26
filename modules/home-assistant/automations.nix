{ lib, config, ... }:
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
        };
      }
    );
  };

  # Pin each automation's HA entity_id to its Nix-side key by emitting
  # an explicit `id`. Without this, HA derives the entity_id from
  # slug(alias), which can drift away from the key — and then anything
  # referencing `e.automation.<key>` resolves to a non-existent entity.
  config.services.home-assistant.config = lib.mkMerge (
    lib.mapAttrsToList (name: auto: {
      "automation ${name}" = auto // { id = name; };
    }) config.hass.automations
  );
}
