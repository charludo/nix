{
  imports = [
    ./_common.nix
  ];

  vm = {
    id = 3002;
    name = "SRV-BLOCKY";

    hardware.cores = 1;
    hardware.memory = 1024;
    hardware.storage = "2G";

    networking.address = "192.168.30.13";
    networking.gateway = "192.168.30.1";
    networking.prefixLength = 24;
    networking.nameservers = [ ];

    networking.openPorts.tcp = [ 53 443 853 ];
    networking.openPorts.udp = [ 53 443 853 ];
  };

  blocky.enable = true;
  services.blocky = {
    settings = {
      ports.dns = 53;
      ports.tls = 853;
      ports.https = 443;
      caching = {
        minTime = "5m";
        maxTime = "30m";
        prefetching = true;
      };
    };
  };

  system.stateVersion = "23.11";
}
