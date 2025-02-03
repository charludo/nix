{ private-settings, secrets, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../common
    ../../users/charlotte/user.nix
  ];

  age.enable = true;
  bluetooth.enable = true;
  fish.enable = true;
  greetd.enable = true;
  gvfs.enable = true;
  nicerFonts.enable = true;
  nvim.enable = true;
  printers.enable = true;
  soundConfig.enable = true;
  soundConfig.enableCombinedAdapter = true;
  screensharing.enable = true;
  snow.enable = true;
  surfshark.enable = true;
  suspend.enable = true;
  wifi.enable = true;
  programs.dconf.enable = true;

  nas.enable = true;
  nas.backup.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.luks.devices."luks-13ca6c92-72b0-41a7-be52-defd57bab492".device =
    "/dev/disk/by-uuid/13ca6c92-72b0-41a7-be52-defd57bab492";

  networking.networkmanager.enable = true;
  networking.hostName = "drone";
  networking.nameservers = [
    "192.168.30.13"
    "1.1.1.1"
  ];

  wireguard = {
    enable = true;
    interface = "hoehle";
    port = 51865;
    ip = "192.168.150.12/32";
    secrets = {
      secretsFilePrivate = secrets.drone-wg-private;
      secretsFilePreshared = secrets.drone-wg-preshared;
      remotePublicKey = private-settings.wireguard.publicKeys.drone;
    };
  };

  musnix = {
    alsaSeq.enable = false;

    rtcqs.enable = true;
    kernel.realtime = true;

    rtirq = {
      resetAll = 1;
      prioLow = 0;
      enable = true;
      nameList = "rtc0 snd";
    };
  };

  hardware.graphics.enable = true;

  system.stateVersion = "23.11";
}
