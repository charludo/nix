{
  lib,
  config,
  pkgs,
  secrets,
  ...
}:
let
  cfg = config.hass.reconciler;
in
{
  options.hass.reconciler = {
    enable = lib.mkEnableOption "pushing Nix-declared device names and entity area assignments into HA via the websocket API";

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

  config = lib.mkIf cfg.enable {
    age.secrets.hass-reconciler-token = {
      rekeyFile = secrets.hass-reconciler-token;
      owner = "hass";
      group = "hass";
    };

    systemd.services.ha-reconciler =
      let
        zhaManifestFile = pkgs.writeText "ha-reconciler-zha.json" (
          builtins.toJSON (
            lib.mapAttrsToList (deviceName: dev: {
              ieee = lib.toLower dev.id;
              name = deviceName;
              area_slug = lib.ha.mkSlug dev.area;
              entities =
                lib.foldlAttrs
                  (
                    acc: nixKey: haDomain:
                    if dev.${nixKey} == [ ] then
                      acc
                    else
                      acc // { ${haDomain} = (acc.${haDomain} or [ ]) ++ dev.${nixKey}; }
                  )
                  { }
                  {
                    binary_sensor = "binary_sensor";
                    diagnostic = "sensor";
                    light = "light";
                    number = "number";
                    select = "select";
                    sensor = "sensor";
                    switch = "switch";
                  };
            }) config.hass.devices.zigbee
          )
        );

        entityManifestFile = pkgs.writeText "ha-reconciler-entities.json" (
          builtins.toJSON (
            lib.concatLists (
              lib.mapAttrsToList
                (
                  domain: source:
                  lib.mapAttrsToList (slug: v: {
                    entity_id = "${domain}.${slug}";
                    area_slug = lib.ha.mkSlug v.area;
                  }) (lib.filterAttrs (_: v: v.area != null) source)
                )
                {
                  input_boolean = config.hass.devices.input_booleans;
                  input_number = config.hass.devices.input_numbers;
                  media_player = config.hass.devices.media_players;
                  vacuum = config.hass.devices.vacuums;
                  fan = config.hass.devices.fans;
                  image = config.hass.devices.images;
                  sun = config.hass.devices.suns;
                  weather = config.hass.devices.weathers;
                  sensor = config.hass.devices.sensors;
                }
            )
          )
        );

        wyomingManifestFile = pkgs.writeText "ha-reconciler-wyoming.json" (
          builtins.toJSON (
            map (
              r:
              let
                area = config.hass.devices.media_players.${lib.removePrefix "media_player." r.target}.area or null;
              in
              {
                match_name = "${r.satellite}-satellite";
                name = r.satellite;
                area_slug = if area == null then null else lib.ha.mkSlug area;
              }
            ) (config.hass.ttsRelay or [ ])
          )
        );
      in
      {
        description = "Reconcile device names and entity areas from Nix into HA";
        after = [ "home-assistant.service" ];
        wants = [ "home-assistant.service" ];
        wantedBy = [ "multi-user.target" ];
        restartTriggers = [
          zhaManifestFile
          entityManifestFile
          wyomingManifestFile
          pkgs.ours.home-assistant.ha-reconciler
        ];
        serviceConfig = {
          Type = "simple";
          DynamicUser = true;
          SupplementaryGroups = [ "hass" ];
          LoadCredential = [ "token:${cfg.tokenPath}" ];
        };
        script = ''
          ${lib.getExe pkgs.ours.home-assistant.ha-reconciler} \
            --url ${lib.escapeShellArg cfg.url} \
            --token-file "$CREDENTIALS_DIRECTORY/token" \
            --manifest ${zhaManifestFile} \
            --entity-manifest ${entityManifestFile} \
            --wyoming-manifest ${wyomingManifestFile} \
            || true
        '';
      };
  };
}
