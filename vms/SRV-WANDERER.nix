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

    hardware.cores = 4;
    hardware.memory = 8192;
    hardware.storage = "32G";

    networking.openPorts.tcp = [ 8090 ];
  };

  age.secrets.wanderer-env.rekeyFile = secrets.wanderer-env;
  services.wanderer = {
    enable = true;
    package = pkgs.ours.wanderer;
    origin = "https://pathfinder.${private-settings.domains.home}";
    openFirewall = true;
    services.pocketbase.url = "http://0.0.0.0:8090";
    secretsFile = config.age.secrets.wanderer-env.path;
  };

  nas.backup.enable = true;
  rsync."wanderer" = {
    tasks = [
      {
        from = "/var/lib/wanderer";
        to = "${config.nas.backup.stateLocation}/wanderer";
        chown = "wanderer:wanderer";
        # this might be a problem upon restore;
        # probably a good idea to rebuild afterwards,
        # since restore likely deletes the symlinked web files.
        extraFlags = "--no-links";
      }
    ];
  };
}
