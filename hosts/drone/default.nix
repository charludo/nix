{ config, ... }:
{
  _module.args.defaultUser = "charlotte";
  imports =
    [
      ./hardware-configuration.nix

      ../common/global

      ../common/optional/bluetooth.nix
      ../common/optional/cups.nix
      ../common/optional/dconf.nix
      ../common/optional/fontconfig.nix
      ../common/optional/greetd.nix
      ../common/optional/gvfs.nix
      ../common/optional/nvim.nix
      ../common/optional/pipewire.nix
      ../common/optional/screensharing.nix
      ../common/optional/surfshark.nix
      ../common/optional/suspend.nix
      ../common/optional/wifi.nix
      ../common/optional/zsh.nix

      ../../users/charlotte/user.nix
    ];

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
