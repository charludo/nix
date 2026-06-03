{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.hass.closestIntent;
in
{
  options.hass.closestIntent.enable = lib.mkEnableOption "closest_intent fuzzy-match conversation agent";

  config = lib.mkIf cfg.enable {
    services.home-assistant.customComponents = [
      pkgs.ours.home-assistant.custom-components.closest_intent
    ];

    services.home-assistant.extraPackages =
      python3Packages: with python3Packages; [
        rapidfuzz
      ];

    services.home-assistant.config.closest_intent = {
      threshold = 70;
      slot_threshold = 50;
      expansion_cap = 16;
      slot_extraction = true;
      include_builtins = false;
      builtin_allowlist = [ ];
    };

    services.home-assistant.config.logger.logs."custom_components.closest_intent" = "debug";
  };
}
