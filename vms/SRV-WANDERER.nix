{
  config,
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
  };

  services.wanderer = {
    enable = true;
    plugins = with pkgs.wanderer.plugins; [ komoot ];
    host = "0.0.0.0";
    openFirewall = true;
    pocketbase.host = "0.0.0.0";
    settings.ORIGIN = "https://pathfinder.${private-settings.domains.home}";
    secrets = {
      POCKETBASE_ENCRYPTION_KEY = config.age.secrets.wanderer-encryption-key.path;
      POCKETBASE_PROXY_SECRET = config.age.secrets.wanderer-proxy-secret.path;
    };
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
