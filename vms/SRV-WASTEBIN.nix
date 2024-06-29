{ inputs, config, ... }:
{
  imports = [ ./_common.nix ];

  vm = {
    id = 2204;
    name = "SRV-WASTEBIN";

    hardware.cores = 1;
    hardware.memory = 1024;
    hardware.storage = "2G";

    networking.address = "192.168.20.39";
    networking.gateway = "192.168.20.34";
    networking.prefixLength = 27;

    networking.openPorts.tcp = [ 8080 ];
    networking.openPorts.udp = [ 8080 ];
  };

  sops.secrets.wastebin = { sopsFile = ./secrets/wastebin-secrets.sops.yaml; };
  services.wastebin = {
    enable = true;
    secretFile = config.sops.secrets.wastebin.path;
    settings = {
      WASTEBIN_BASE_URL = inputs.private-settings.domains.wastebin;
      WASTEBIN_ADDRESS_PORT = "0.0.0.0:8080";
    };
  };

  system.stateVersion = "23.11";
}
