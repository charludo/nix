{ config, private-settings, ... }:
{
  vm = {
    id = 2207;
    name = "SRV-AUDIOBOOKSHELF";

    hardware.cores = 4;
    hardware.memory = 16384;
    hardware.storage = "32G";

    networking.nameservers = private-settings.upstreamDNS.ips;
  };

  services.audiobookshelf = {
    enable = true;
    openFirewall = true;
    host = "0.0.0.0";
  };

  nas.enable = true;
  nas.extraUsers = [ config.services.audiobookshelf.user ];

  nas.backup.enable = true;
  rsync."audiobookshelf" = {
    tasks = [
      {
        from = "/var/lib/${config.services.audiobookshelf.dataDir}";
        to = "${config.nas.backup.stateLocation}/audiobookshelf";
        chown = "${config.services.audiobookshelf.user}:${config.services.audiobookshelf.group}";
      }
    ];
  };
}
