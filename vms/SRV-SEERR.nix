{ config, private-settings, ... }:
let
  dataDir = "/var/lib/jellyseerr";
in
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
        port = config.services.jellyseerr.port;
      }
    ];
  };

  services.jellyseerr = {
    enable = true;
    openFirewall = true;
  };

  nas.backup.enable = true;
  rsync."jellyseerr" = {
    tasks = [
      {
        from = "${dataDir}";
        to = "${config.nas.backup.stateLocation}/jellyseerr";
      }
    ];
  };
}
