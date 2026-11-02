{
  config,
  lib,
  pkgs,
  private-settings,
  secrets,
  ...
}:
{
  vm = {
    id = 2220;
    name = "SRV-WANDERER";
    unsupervisedUpdates = true;

    hardware.cores = 4;
    hardware.memory = 8192;
    hardware.storage = "32G";

    networking.openPorts.tcp = [ 8090 ];
  };

  age.secrets = {
    wanderer-meili-master-key.rekeyFile = secrets.wanderer-meili-master-key;
    wanderer-encryption-key.rekeyFile = secrets.wanderer-encryption-key;
    wanderer-proxy-secret.rekeyFile = secrets.wanderer-proxy-secret;
    wanderer-protomaps-api-key.rekeyFile = secrets.wanderer-protomaps-api-key;
  };

  services.wanderer = {
    enable = true;
    plugins = with pkgs.wanderer.plugins; [ komoot ];
    host = "0.0.0.0";
    openFirewall = true;
    pocketbase.host = "0.0.0.0";
    settings = {
      ORIGIN = "https://pathfinder.${private-settings.domains.home}";
      VALHALLA_URL = "https://valhalla1.openstreetmap.de";
      NOMINATIM_URL = "https://nominatim.openstreetmap.org";
      OVERPASS_API_URL = "https://overpass-api.de";
    };
    secrets = {
      POCKETBASE_ENCRYPTION_KEY = config.age.secrets.wanderer-encryption-key.path;
      POCKETBASE_PROXY_SECRET = config.age.secrets.wanderer-proxy-secret.path;
    };
  };

  # Workaround can be removed after: https://github.com/NixOS/nixpkgs/pull/582248
  systemd.services.wanderer-web = {
    script = lib.mkBefore ''
      export PROTOMAPS_API_KEY="$(< "$CREDENTIALS_DIRECTORY/PROTOMAPS_API_KEY")"
    '';
    serviceConfig.LoadCredential = [
      "PROTOMAPS_API_KEY:${config.age.secrets.wanderer-protomaps-api-key.path}"
    ];
  };

  services.meilisearch.masterKeyFile = config.age.secrets.wanderer-meili-master-key.path;

  nas.backup.enable = true;
  rsync."wanderer" = {
    tasks = [
      {
        from = "/var/lib/wanderer";
        to = "${config.nas.backup.stateLocation}/wanderer";
        chown = "wanderer:wanderer";
      }
    ];
  };
}
