{ lib, pkgs, ... }:
{
  _module.args.defaultUser = "marie";
  imports =
    [
      # ./hardware-configuration.nix

      ../common/global

      ../common/optional/dconf.nix
      ../common/optional/pipewire.nix
      ../common/optional/vmify.nix

      ../../users/marie/user.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.qemuGuest.enable = true;
  users.mutableUsers = lib.mkForce true;

  networking = {
    hostName = "CL-NIX-3";
    interfaces = {
      ens18.ipv4.addresses = [{
        # address = "192.168.30.95";
        address = "192.168.130.99";
        prefixLength = 24;
      }];
    };
    # defaultGateway = "192.168.30.1";
    defaultGateway = "192.168.130.1";
    nameservers = [ "1.1.1.1" ];
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
