{
  config,
  lib,
  private-settings,
  ...
}:
{
  vm = {
    id = 2223;
    name = "SRV-SEERR";

    hardware.cores = 2;
    hardware.memory = 4096;
    hardware.storage = "32G";

    networking.nameservers = private-settings.upstreamDNS.ips;
    certsFor = [
      {
        name = "seerr";
        port = config.services.seerr.port;
      }
    ];
  };

  services.seerr = {
    enable = true;
    openFirewall = true;
    configDir = "/var/lib/seerr";
  };
  systemd.services.seerr.serviceConfig.StateDirectory = lib.mkForce "seerr";

  nas.backup.enable = true;
  rsync."seerr" = {
    tasks = [
      {
        from = "${config.services.seerr.configDir}";
        to = "${config.nas.backup.stateLocation}/seerr";
      }
    ];
  };
}
