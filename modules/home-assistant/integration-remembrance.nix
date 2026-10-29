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

    duckling = {
      enable = lib.mkEnableOption "Duckling for the services that take a sentence (`parse`, `create_from_text`)";
      port = lib.mkOption {
        type = lib.types.port;
        default = 8732;
        description = "Port Duckling listens on, on localhost.";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        services.home-assistant.customComponents = [ pkgs.ours.hass-remembrance ];
        services.home-assistant.config.remembrance = cfg.settings;
        services.home-assistant.config.logger.logs."custom_components.remembrance" = "debug";
      }
      (lib.mkIf cfg.duckling.enable {
        hass.remembrance.settings.duckling_url = "http://127.0.0.1:${toString cfg.duckling.port}";

        systemd.services.duckling = {
          description = "Duckling, times and durations in text";
          wantedBy = [ "multi-user.target" ];
          before = [ "home-assistant.service" ];
          serviceConfig = {
            ExecStart = lib.escapeShellArgs [
              (lib.getExe' pkgs.ours.duckling "duckling-example-exe")
              "--address"
              "127.0.0.1"
              "--port"
              (toString cfg.duckling.port)
              "--no-access-log"
              "--no-error-log"
            ];
            DynamicUser = true;
            RuntimeDirectory = "duckling";
            WorkingDirectory = "%t/duckling";
            Restart = "on-failure";
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            PrivateDevices = true;
            NoNewPrivileges = true;
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
            ];
          };
        };
      })
    ]
  );
}
