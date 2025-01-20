{ config, private-settings, secrets, ... }:
{
  imports = [ ./_common.nix ];

  vm = {
    id = 2204;
    name = "SRV-WASTEBIN";

    hardware.cores = 1;
    hardware.memory = 1024;
    hardware.storage = "2G";

    networking.openPorts.tcp = [ 8080 ];
    networking.openPorts.udp = [ 8080 ];
  };

  sops.secrets.wastebin = { sopsFile = secrets.wastebin; };
  services.wastebin = {
    enable = true;
    secretFile = config.sops.secrets.wastebin.path;
    settings = {
      WASTEBIN_BASE_URL = private-settings.domains.wastebin;
      WASTEBIN_ADDRESS_PORT = "0.0.0.0:8080";
    };
  };

  system.stateVersion = "23.11";
}
