{ private-settings, ... }:
{
  imports = [ ../users/marie/user.nix ];

  vm = {
    id = 3020;
    name = "CL-NIX-3";

    hardware.cores = 4;
    hardware.memory = 4096;
    hardware.storage = "8G";

    networking = {
      address = "192.168.130.99";
      gateway = "192.168.130.1";
      nameservers = private-settings.upstreamDNS.ips;
      prefixLength = 24;
    };

    clientDevice.enable = true;
    clientDevice.kde = true;
  };
}
