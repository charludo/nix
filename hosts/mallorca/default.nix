{
  lib,
  private-settings,
  secrets,
  ...
}:
{
  _module.args.defaultUser = "charlotte";
  imports = [
    ./hardware-configuration.nix
    ../common
    ../../users/charlotte/user.nix
  ];

  nas.enable = false;
  nas.backup.enable = false;

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

  wireguard = {
    enable = true;
    autoStart = true;
    interface = "hoehle";
    port = 51865;
    ip = "192.168.150.12/32";
    secrets = {
      secretsFile = secrets.drone;
      remotePublicKey = private-settings.wireguard.publicKeys.drone;
    };
  };

  hardware.graphics.enable = true;

  system.stateVersion = "23.11";
}
