{ config, lib, ... }:
{
  _module.args.defaultUser = "charlotte";
  imports =
    [
      ./hardware-configuration.nix

      ../common/global

      ../common/optional/dconf.nix
      ../common/optional/fontconfig.nix
      ../common/optional/greetd.nix
      ../common/optional/gvfs.nix
      ../common/optional/nvim.nix
      ../common/optional/pipewire.nix
      ../common/optional/plymouth.nix
      ../common/optional/screensharing.nix
      ../common/optional/surfshark.nix
      ../common/optional/suspend.nix
      ../common/optional/zsh.nix

      ../../users/charlotte/user.nix
    ];

  enableNas = false;
  enableNasBackup = false;

  console.keyMap = lib.mkForce "es";
  time.timeZone = "Europe/Madrid";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;
  networking.hostName = "mallorca";
  networking.nameservers = [ "1.1.1.1" ];

  networking.firewall.allowedUDPPorts = [ 51865 ];
  networking.firewall.checkReversePath = "loose";
  sops.secrets.wireguard-mallorca = { };
  environment.etc."NetworkManager/system-connections/hoehle.nmconnection" = {
    source = "${config.sops.secrets.wireguard-mallorca.path}";
  };

  hardware.graphics.enable = true;

  system.stateVersion = "23.11";
}
