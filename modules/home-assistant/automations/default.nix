{ lib, config, ... }:
let
  cfg = config.hass;

  automationSubmodule = {
    options = {
      alias = lib.mkOption {
        type = lib.types.str;
      };
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
  };

  config.services.home-assistant.config = lib.mkMerge (
    lib.mapAttrsToList (name: auto: {
      "automation ${name}" = auto;
    }) cfg.automations
  );
}
