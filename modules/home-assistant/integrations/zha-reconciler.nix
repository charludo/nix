{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hass;
  rcfg = cfg.zha.reconciler;
  inherit (lib.ha) mkSlug;

  # ieees are normalised to lowercase for case-insensitive matching
  # against whatever ZHA returns.
  zhaManifest = lib.mapAttrsToList (deviceName: dev: {
    ieee = lib.toLower dev.id;
    name = deviceName;
    area_slug = mkSlug dev.area;
  }) cfg.devices.zigbee;

  # Every non-zigbee declared device that has an area, addressed by its
  # predictable entity_id. The reconciler prefers to set area on the
  # owning device when one exists, otherwise falls back to entity-level.
  collectAreas =
    domain: attrs:
    lib.mapAttrsToList (slug: v: {
      entity_id = "${domain}.${slug}";
      area_slug = mkSlug v.area;
    }) (lib.filterAttrs (_: v: v.area != null) attrs);

  entityManifest = lib.concatLists [
    (collectAreas "input_boolean" cfg.devices.input_booleans)
    (collectAreas "input_number" cfg.devices.input_numbers)
    (collectAreas "media_player" cfg.devices.media_players)
    (collectAreas "vacuum" cfg.devices.vacuums)
    (collectAreas "fan" cfg.devices.fans)
    (collectAreas "image" cfg.devices.images)
    (collectAreas "sun" cfg.devices.suns)
    (collectAreas "weather" cfg.devices.weathers)
    (collectAreas "sensor" cfg.devices.sensors)
  ];

  zhaManifestFile = pkgs.writeText "zha-reconciler-zha.json" (builtins.toJSON zhaManifest);
  entityManifestFile = pkgs.writeText "zha-reconciler-entities.json" (builtins.toJSON entityManifest);
in
{
  options.hass.zha.reconciler = {
    enable = lib.mkEnableOption "zha-reconciler: push Nix-declared device names and areas into HA's device registry via the websocket API";

    url = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8123";
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
      # Re-run whenever a manifest or the script changes, via
      # switch-to-configuration restart logic.
      restartTriggers = [
        zhaManifestFile
        entityManifestFile
        pkgs.ours.home-assistant.zha-reconciler
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 30;
        DynamicUser = true;
        SupplementaryGroups = [ "hass" ];
        # Exposes the token at $CREDENTIALS_DIRECTORY/token without the
        # unit user needing direct access to the agenix path.
        LoadCredential = [ "token:${rcfg.tokenPath}" ];
      };
      script = ''
        exec ${pkgs.ours.home-assistant.zha-reconciler}/bin/zha-reconciler \
          --url ${lib.escapeShellArg rcfg.url} \
          --token-file "$CREDENTIALS_DIRECTORY/token" \
          --manifest ${zhaManifestFile} \
          --entity-manifest ${entityManifestFile}
      '';
    };
  };
}
