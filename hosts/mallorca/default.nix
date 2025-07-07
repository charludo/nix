{
  lib,
  private-settings,
  secrets,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../common
    ../../users/charlotte/user.nix
  ];

  nas.enable = false;
  nas.backup.enable = false;

  age.enable = true;
  fish.enable = true;
  graphicalFixes.enable = true;
  greetd.enable = true;
  gvfs.enable = true;
  nicerFonts.enable = true;
  nvim.enable = true;
  plymouth.enable = true;
  plymouth.theme = "red_loader";
  snow.enable = true;
  soundConfig.enable = true;
  screensharing.enable = true;
  surfshark.enable = true;
  suspend.enable = true;
  programs.dconf.enable = true;

  console.keyMap = lib.mkForce "es";
  time.timeZone = "Europe/Madrid";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;
  networking.hostName = "mallorca";
  networking.nameservers = private-settings.upstreamDNS.ips;

  wireguard = {
    enable = true;
    autoStart = true;
    interface = "hoehle";
    port = 51865;
    ip = "192.168.150.12/32";
    secrets = {
      secretsFilePrivate = secrets.drone-wg-private;
      secretsFilePreshared = secrets.drone-wg-preshared;
      remotePublicKey = private-settings.wireguard.publicKeys.drone;
    };
  };

  hardware.graphics.enable = true;

  system.stateVersion = "23.11";
}
