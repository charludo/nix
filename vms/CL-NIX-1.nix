{ lib, pkgs, ... }:
{
  _module.args.defaultUser = "marie";
  imports = [
    ./_common.nix

    ../hosts/common/optional/dconf.nix
    ../hosts/common/optional/pipewire.nix
    ../hosts/common/optional/vmify.nix

    ../users/marie/user.nix
  ];

  users.mutableUsers = lib.mkForce true;
  enableNasBackup = true;

  vm = {
    id = 3020;
    name = "CL-NIX-1";

    hardware.cores = 4;
    hardware.memory = 4096;
    hardware.storage = "8G";
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
