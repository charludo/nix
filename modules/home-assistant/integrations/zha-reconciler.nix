{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hass;
  rcfg = cfg.zha.reconciler;
  mkSlug = lib.ha.mkSlug;

  # [{ ieee, name, area_slug }]; ieees are normalised to lowercase for
  # case-insensitive matching against whatever ZHA returns.
  manifest = lib.mapAttrsToList (deviceName: dev: {
    ieee = lib.toLower dev.id;
    name = deviceName;
    area_slug = mkSlug dev.area;
  }) cfg.devices.zigbee;

  manifestFile = pkgs.writeText "zha-reconciler-manifest.json" (builtins.toJSON manifest);

  reconciler = pkgs.ours.home-assistant.zha-reconciler;
in
{
  options.hass.zha.reconciler = {
    enable = lib.mkEnableOption "zha-reconciler: push Nix-declared device names and areas into HA's device registry via the websocket API";

    url = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8123";
      description = "Base URL of the local Home Assistant instance";
    };

    tokenPath = lib.mkOption {
      type = lib.types.path;
      default = "/run/agenix/hass-reconciler-token";
      description = ''
        Path to a file containing a Home Assistant long-lived access token.
        Create the token in HA (user profile -> Security -> Long-lived tokens),
        store it as an agenix secret named e.g. hass-reconciler-token, and
        plumb it in alongside the existing hass-secrets entry:

          age.secrets.hass-reconciler-token = {
            rekeyFile = secrets.hass-reconciler-token;
            owner = "hass";
            group = "hass";
          };
      '';
    };
  };

  config = lib.mkIf rcfg.enable {
    systemd.services.zha-reconciler = {
      description = "Reconcile ZHA device names + areas from Nix into HA";
      after = [ "home-assistant.service" ];
      wants = [ "home-assistant.service" ];
      wantedBy = [ "multi-user.target" ];
      # Re-run whenever the manifest or script hash changes (i.e. whenever
      # devices.zigbee changes), via switch-to-configuration restart logic.
      restartTriggers = [
        manifestFile
        reconciler
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 30;
        DynamicUser = true;
        SupplementaryGroups = [ "hass" ];
        LoadCredential = [ "token:${rcfg.tokenPath}" ];
        # NoNewPrivileges, ProtectSystem, etc. left to systemd defaults +
        # DynamicUser hardening (already strong).
      };
      # LoadCredential exposes the secret at $CREDENTIALS_DIRECTORY/token,
      # avoiding any need for the unit user to read the agenix path directly.
      script = ''
        exec ${reconciler}/bin/zha-reconciler \
          --url ${lib.escapeShellArg rcfg.url} \
          --token-file "$CREDENTIALS_DIRECTORY/token" \
          --manifest ${manifestFile}
      '';
    };
  };
}
