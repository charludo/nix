{ config, lib, ... }:
{
  _module.args.defaultUser = "charlotte";
  imports =
    [
      ./hardware-configuration.nix
      ../common
      ../../users/charlotte/user.nix
    ];

  enableNas = false;
  enableNasBackup = false;

  fish.enable = true;
  nicerFonts.enable = true;
  greetd.enable = true;
  gvfs.enable = true;
  nvim.enable = true;
  plymouth.enable = true;
  plymouth.theme = "red_loader";
  soundConfig.enable = true;
  screensharing.enable = true;
  surfshark.enable = true;
  suspend.enable = true;

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
