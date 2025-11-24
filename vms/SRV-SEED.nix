{ config, ... }:
{
  vm = {
    id = 3023;
    name = "SRV-SEED";

    hardware.cores = 2;
    hardware.memory = 8192;
    hardware.storage = "32G";

    networking.openPorts.tcp = [ 9000 ];
    networking.openPorts.udp = [ 9000 ];
  };

  services = {
    qbittorrent.enable = true;
    qbittorrent.openFirewall = true;
    qbittorrent.webuiPort = 8112;
  };

  nas.enable = true;
  nas.extraUsers = [
    config.services.qbittorrent.user
  ];
}
