{ pkgs, ... }:
{
  vm = {
    id = 2202;
    name = "SRV-PDF";

    hardware.cores = 2;
    hardware.memory = 1024;
    hardware.storage = "8G";
  };

  services.bentopdf = {
    enable = true;
    package = pkgs.ours.bentopdf.overrideAttrs { SIMPLE_MODE = "true"; };
    openFirewall = true;
    port = 3000;
  };

  system.stateVersion = "23.11";
}
