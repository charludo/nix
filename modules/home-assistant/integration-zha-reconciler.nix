{
  lib,
  config,
  pkgs,
  secrets,
  ...
}:
let
  cfg = config.hass;
  rcfg = cfg.zha.reconciler;
  inherit (lib.ha) mkSlug;

  zigbeeDomainMap = {
    binary_sensor = "binary_sensor";
    diagnostic = "sensor";
    light = "light";
    number = "number";
    select = "select";
    sensor = "sensor";
    switch = "switch";
  };

  declaredEntitiesByDomain =
    dev:
    lib.foldl' (
      acc: nixKey:
      let
        haDomain = zigbeeDomainMap.${nixKey};
        suffixes = dev.${nixKey} or [ ];
      in
      if suffixes == [ ] then acc else acc // { ${haDomain} = (acc.${haDomain} or [ ]) ++ suffixes; }
    ) { } (lib.attrNames zigbeeDomainMap);

  zhaManifest = lib.mapAttrsToList (deviceName: dev: {
    ieee = lib.toLower dev.id;
    name = deviceName;
    area_slug = mkSlug dev.area;
    entities = declaredEntitiesByDomain dev;
  }) cfg.devices.zigbee;

  collectAreas =
    domain: attrs:
    lib.mapAttrsToList (slug: v: {
      entity_id = "${domain}.${slug}";
      area_slug = mkSlug v.area;
    }) (lib.filterAttrs (_: v: v.area != null) attrs);

  satelliteAreas =
    let
      mps = cfg.devices.media_players;
    in
    lib.filter (e: e != null) (
      map (
        r:
        let
          slug = lib.removePrefix "media_player." r.target;
          area = mps.${slug}.area or null;
        in
        if area == null then
          null
        else
          {
            entity_id = r.satellite;
            area_slug = mkSlug area;
          }
      ) (cfg.ttsRelay or [ ])
    );

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
    satelliteAreas
  ];

  zhaManifestFile = pkgs.writeText "zha-reconciler-zha.json" (builtins.toJSON zhaManifest);
  entityManifestFile = pkgs.writeText "zha-reconciler-entities.json" (builtins.toJSON entityManifest);
in
{
  options.hass.zha.reconciler = {
    enable = lib.mkEnableOption "pushing Nix-declared device names and areas into HA's device registry via the websocket API";

    url = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8123";
      description = "Base URL of the local Home Assistant instance";
    };

    tokenPath = lib.mkOption {
      type = lib.types.path;
      description = "Path to a file containing a HA long-lived access token";
    };
  };

  config = lib.mkIf rcfg.enable {
    age.secrets.hass-reconciler-token = {
      rekeyFile = secrets.hass-reconciler-token;
      owner = "hass";
      group = "hass";
    };

    systemd.services.zha-reconciler = {
      description = "Reconcile ZHA device names + areas from Nix into HA";
      after = [ "home-assistant.service" ];
      wants = [ "home-assistant.service" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [
        zhaManifestFile
        entityManifestFile
        pkgs.ours.home-assistant.zha-reconciler
      ];
      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        SupplementaryGroups = [ "hass" ];
        LoadCredential = [ "token:${rcfg.tokenPath}" ];
      };
      script = ''
        ${lib.getExe pkgs.ours.home-assistant.zha-reconciler} \
          --url ${lib.escapeShellArg rcfg.url} \
          --token-file "$CREDENTIALS_DIRECTORY/token" \
          --manifest ${zhaManifestFile} \
          --entity-manifest ${entityManifestFile} \
          || true
      '';
    };
  };
}
