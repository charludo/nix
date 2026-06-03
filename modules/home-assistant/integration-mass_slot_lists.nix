{
  config,
  lib,
  pkgs,
  secrets,
  ...
}:
let
  cfg = config.hass.massSlotLists;
  hassCfgDir = config.services.home-assistant.configDir;
  # State-side YAML; HA sees it via a tmpfiles symlink under custom_sentences/.
  stateDir = "/var/lib/mass-slot-lists";
  stateFile = "${stateDir}/${cfg.language}.yaml";
  linkPath = "${hassCfgDir}/custom_sentences/${cfg.language}/mass_lists.yaml";
in
{
  # Snapshot Music Assistant's library (artists + albums) into a
  # hassil slot-list YAML under `custom_sentences/<lang>/`. closest_intent
  # picks the file up automatically (see _load_custom_sentences in its
  # conversation.py); stock HA conversation reads it too. Refreshed on
  # every MA start and on a timer so new library additions become
  # voice-addressable without a HA restart.
  options.hass.massSlotLists = {
    enable = lib.mkEnableOption "Music Assistant -> HA custom_sentences slot list sync";

    massUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8095";
      description = "Music Assistant base URL";
    };

    massTokenPath = lib.mkOption {
      type = lib.types.path;
      default = "/run/agenix/mass-token";
      description = ''
        Path to a file containing a Music Assistant long-lived token.
        MA schema >= 28 requires authentication even on the local socket,
        so this is a separate token from ``hass.zha.reconciler.tokenPath``.
        Mint via the MA UI -> Settings -> Security -> Long-lived tokens
        and plumb in alongside the existing hass secrets:

          age.secrets.mass-token = {
            rekeyFile = secrets.mass-token;
            owner = "hass";
            group = "hass";
          };
      '';
    };

    hassUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8123";
      description = "Home Assistant base URL (used for conversation.reload)";
    };

    hassTokenPath = lib.mkOption {
      type = lib.types.path;
      default = "/run/agenix/hass-mass-token";
      description = ''
        Path to a HA long-lived token, used here to POST conversation.reload
        after a slot-list refresh. Kept separate from the zha-reconciler
        token so revoking one doesn't break the other.
      '';
    };

    language = lib.mkOption {
      type = lib.types.str;
      default = config.hass.voice.defaultLanguage;
      defaultText = lib.literalExpression "config.hass.voice.defaultLanguage";
      description = "Language code; written into the YAML's `language:` field and used as the custom_sentences subdir";
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

    # Two rules: (1) make sure the state dir is hass-owned so HA can
    # read what we write here — `StateDirectory=` only sets ownership
    # on initial create, so a stale DynamicUser-owned directory from
    # an earlier service revision would still block writes; (2) symlink
    # the state file into HA's custom_sentences/<lang>/. The symlink
    # dangles before the first sync run; HA tolerates an unreadable
    # file in the directory.
    systemd.tmpfiles.settings."20-mass-slot-lists" = {
      ${linkPath}."L+".argument = stateFile;
    };

    systemd.services.mass-slot-lists = {
      description = "Sync Music Assistant artists + albums into HA custom_sentences";
      # Run after both MA and HA are up. Wanted-by MA so each MA restart
      # triggers a fresh sync; the timer handles the steady-state cadence.
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
        # Run as hass so HA (also hass) can read the state file
        # directly. DynamicUser would route the dir through
        # /var/lib/private (0700 root:root), which HA can't traverse.
        User = "hass";
        Group = "hass";
        StateDirectory = "mass-slot-lists";
        # Exposes tokens at $CREDENTIALS_DIRECTORY/{mass,hass}-token; the
        # script picks them up by default.
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
      description = "Hourly refresh of Music Assistant slot lists";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = cfg.interval;
        Unit = "mass-slot-lists.service";
      };
    };
  };
}
