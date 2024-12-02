{
  config,
  lib,
  pkgs,
  secrets,
  ...
}:
let
  cfg = config.hass.massSlotLists;
  stateFile = "/var/lib/mass-slot-lists/${cfg.language}.yaml";
in
{
  options.hass.massSlotLists = {
    enable = lib.mkEnableOption "Music Assistant -> HA custom_sentences slot list sync";

    massUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8095";
      description = "Music Assistant base URL";
    };

    massTokenPath = lib.mkOption {
      type = lib.types.path;
      description = "Path to a file containing a Music Assistant long-lived token";
    };

    hassUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8123";
      description = "Home Assistant base URL (used for conversation.reload)";
    };

    hassTokenPath = lib.mkOption {
      type = lib.types.path;
      description = "Path to a file containing a Home Assistant long-lived token";
    };

    language = lib.mkOption {
      type = lib.types.str;
      default = config.hass.voice.defaultLanguage;
      defaultText = lib.literalExpression "config.hass.voice.defaultLanguage";
      description = "Language code to use";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "1h";
      description = "Refresh cadence (systemd OnUnitActiveSec value)";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.mass-token = {
      rekeyFile = secrets.mass-token;
      owner = "hass";
      group = "hass";
    };

    age.secrets.hass-mass-token = {
      rekeyFile = secrets.hass-mass-token;
      owner = "hass";
      group = "hass";
    };

    systemd.tmpfiles.rules = [
      "L+ ${config.services.home-assistant.configDir}/custom_sentences/${cfg.language}/mass_lists.yaml - - - - ${stateFile}"
    ];

    systemd.services.mass-slot-lists = {
      description = "Sync Music Assistant artists + albums into HA custom_sentences";
      after = [
        "music-assistant.service"
        "home-assistant.service"
      ];
      wants = [
        "music-assistant.service"
        "home-assistant.service"
      ];
      wantedBy = [ "music-assistant.service" ];

      serviceConfig = {
        Type = "oneshot";
        User = "hass";
        Group = "hass";
        StateDirectory = "mass-slot-lists";
        LoadCredential = [
          "mass-token:${cfg.massTokenPath}"
          "hass-token:${cfg.hassTokenPath}"
        ];
        ExecStart = lib.concatStringsSep " " [
          (lib.getExe pkgs.ours.home-assistant.mass-slot-lists)
          "--mass-url=${cfg.massUrl}"
          "--hass-url=${cfg.hassUrl}"
          "--language=${cfg.language}"
          "--output=${stateFile}"
        ];
      };
    };

    systemd.timers.mass-slot-lists = {
      description = "Refresh Music Assistant slot lists every ${cfg.interval}";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = cfg.interval;
        Unit = "mass-slot-lists.service";
      };
    };
  };
}
