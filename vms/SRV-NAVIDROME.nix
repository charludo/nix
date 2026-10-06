{ config, private-settings, ... }:
{
  vm = {
    id = 2226;
    name = "SRV-NAVIDROME";

    hardware.cores = 2;
    hardware.memory = 4096;
    hardware.storage = "32G";

    networking.nameservers = private-settings.upstreamDNS.ips;
  };

  services.navidrome = {
    enable = true;
    openFirewall = true;
    settings = {
      Address = "0.0.0.0";
      MusicFolder = "${config.nas.location}/Musik";
    };
  };

  systemd.services.navidrome = {
    after = [ "media-NAS.mount" ];
    partOf = [ "media-NAS.mount" ];
  };

  nas.enable = true;
  nas.extraUsers = [ config.services.navidrome.user ];

  nas.backup.enable = true;
  rsync."navidrome" = {
    tasks = [
      {
        from = "/var/lib/navidrome";
        to = "${config.nas.backup.stateLocation}/navidrome";
        chown = "${config.services.navidrome.user}:${config.services.navidrome.group}";
      }
    ];
  };
}
