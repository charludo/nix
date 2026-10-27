{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.hass.remembrance;
in
{
  options.hass.remembrance = {
    enable = lib.mkEnableOption "remembrance, central timers, reminders and alarms";

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      example = lib.literalExpression ''
        {
          ring_script = "script.remembrance_ring";
          ring.timer = { interval = 20; limit = 120; };
          snooze_delay = 600;
        }
      '';
      description = "The `remembrance:` block in configuration.yaml (see the integration's README).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.home-assistant.customComponents = [ pkgs.ours.hass-remembrance ];
    services.home-assistant.config.remembrance = cfg.settings;
    services.home-assistant.config.logger.logs."custom_components.remembrance" = "debug";
  };
}
