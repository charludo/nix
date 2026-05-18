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
  zhaManifest = lib.mapAttrsToList (deviceName: dev: {
    ieee = lib.toLower dev.id;
    name = deviceName;
    area_slug = mkSlug dev.area;
  }) cfg.devices.zigbee;

  # [{ entity_id, area_slug }]: every non-zigbee declared device that has
  # an area, addressed by its predictable entity_id. The reconciler will
  # prefer to set area on the owning device when one exists, otherwise
  # fall back to entity-level area assignment.
  entityManifest =
    let
      collect =
        domain: attrs:
        lib.mapAttrsToList (slug: v: {
          entity_id = "${domain}.${slug}";
          area_slug = mkSlug v.area;
        }) (lib.filterAttrs (_: v: v.area != null) attrs);
      # Mobile-app phones don't have an `area` field in their submodule,
      # so they're naturally excluded. If you ever want phone areas, add
      # `area` to the mobile_apps submodule and include them here as
      # device_tracker.<slug>.
    in
    lib.concatLists [
      (collect "input_boolean" cfg.devices.input_booleans)
      (collect "input_number" cfg.devices.input_numbers)
      (collect "media_player" cfg.devices.media_players)
      (collect "vacuum" cfg.devices.vacuums)
      (collect "fan" cfg.devices.fans)
      (collect "image" cfg.devices.images)
      (collect "sun" cfg.devices.suns)
      (collect "weather" cfg.devices.weathers)
      (collect "sensor" cfg.devices.sensors)
    ];

  zhaManifestFile = pkgs.writeText "zha-reconciler-zha.json" (builtins.toJSON zhaManifest);
  entityManifestFile = pkgs.writeText "zha-reconciler-entities.json" (builtins.toJSON entityManifest);

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
        zhaManifestFile
        entityManifestFile
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
          --manifest ${zhaManifestFile} \
          --entity-manifest ${entityManifestFile}
      '';
    };
  };
}
