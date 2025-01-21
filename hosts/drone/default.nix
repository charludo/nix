{ config, ... }:
{
  _module.args.defaultUser = "charlotte";
  imports =
    [
      ./hardware-configuration.nix
      ../common
      ../../users/charlotte/user.nix
    ];

  bluetooth.enable = true;
  fish.enable = true;
  greetd.enable = true;
  gvfs.enable = true;
  musnix.enable = true;
  nicerFonts.enable = true;
  nvim.enable = true;
  printers.enable = true;
  soundConfig.enable = true;
  soundConfig.enableCombinedAdapter = true;
  screensharing.enable = true;
  surfshark.enable = true;
  suspend.enable = true;
  wifi.enable = true;

  enableNas = true;
  enableNasBackup = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.luks.devices."luks-13ca6c92-72b0-41a7-be52-defd57bab492".device = "/dev/disk/by-uuid/13ca6c92-72b0-41a7-be52-defd57bab492";

  networking.networkmanager.enable = true;
  networking.hostName = "drone";
  networking.nameservers = [ "192.168.30.13" "1.1.1.1" ];

  networking.firewall.allowedUDPPorts = [ 51865 ];
  networking.firewall.checkReversePath = "loose";
  sops.secrets.wireguard-drone = { };
  environment.etc."NetworkManager/system-connections/hoehle.nmconnection" = {
    source = "${config.sops.secrets.wireguard-drone.path}";
  };

  hardware.graphics.enable = true;

  system.stateVersion = "23.11";
}
