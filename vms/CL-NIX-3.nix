{ lib, pkgs, ... }:
{
  _module.args.defaultUser = "marie";
  imports = [
    ./_common.nix
    ../users/marie/user.nix
  ];

  soundConfig.enable = true;

  users.mutableUsers = lib.mkForce true;

  vm = {
    id = 3020;
    name = "CL-NIX-3";

    hardware.cores = 4;
    hardware.memory = 4096;
    hardware.storage = "8G";

    networking = {
      address = "192.168.130.99";
      gateway = "192.168.130.1";
      nameservers = [ "1.1.1.1" ];
      prefixLength = 24;
    };
  };

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;

  environment.plasma5.excludePackages = with pkgs.libsForQt5; [
    plasma-browser-integration
  ];

  services.xrdp = {
    enable = true;
    defaultWindowManager = "startplasma-x11";
    openFirewall = true;
  };

  system.stateVersion = "23.11";
}
