{ pkgs, private-settings, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../common
    ../../users/charlotte/user.nix
  ];

  age.enable = true;
  # androidUtils.enable = true;
  bluetooth.enable = true;
  docker.enable = true;
  # eid.enable = true;
  fish.enable = true;
  graphicalFixes.enable = true;
  greetd.enable = true;
  gvfs.enable = true;
  ld.enable = true;
  nicerFonts.enable = true;
  nvim.enable = true;
  # onlykey.enable = true;
  printers.enable = true;
  rsync.enable = true;
  screensharing.enable = true;
  snow.enable = true;
  soundConfig.enable = true;
  surfshark.enable = true;
  suspend.enable = true;
  suspend.gigabyteFix = true;
  tailscale.enable = true;
  wifi.enable = true;
  programs.dconf.enable = true;

  age.secrets.yubikey-sudo.rekeyFile = private-settings.yubikeys.zakalwe.sudoFile;

  nas.enable = true;
  nas.backup.enable = true;

  environment.systemPackages = [ pkgs.ntfs3g ];
  fileSystems."/media/Media" = {
    device = "/dev/disk/by-uuid/A01C13B21C138288";
    fsType = "ntfs-3g";
  };

  boot.initrd.luks.devices = {
    "luks-f6e55a8b-1146-43dc-81c7-7bf5deb78fa6" = {
      device = "/dev/disk/by-uuid/f6e55a8b-1146-43dc-81c7-7bf5deb78fa6";
      keyFile = "/dev/disk/by-id/usb-Intenso_Micro_Line_6414041056097521862-0:0";
      keyFileSize = 4096;
      fallbackToPassword = true;
      bypassWorkqueues = true;
    };
    "luks-6caf2086-fb9b-4668-b5d8-2f4df815c58b" = {
      device = "/dev/disk/by-uuid/6caf2086-fb9b-4668-b5d8-2f4df815c58b";
      keyFile = "/dev/disk/by-id/usb-Intenso_Micro_Line_6414041056097521862-0:0";
      keyFileSize = 4096;
      fallbackToPassword = true;
      bypassWorkqueues = true;
    };
  };

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    devices = [ "nodev" ];
    useOSProber = true;
  };

  boot.initrd.kernelModules = [
    "amdgpu"
    "usb_storage"
  ];
  boot.kernelParams = [
    "video=DP-2:2560x1440@59.91"
    "video=DP-3:2560x1440@59.91"
  ];

  networking.networkmanager.enable = true;
  networking.hostName = "hub";
  networking.nameservers = [ "192.168.30.13" ];

  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  hardware.graphics.extraPackages = [
    pkgs.amdvlk
    pkgs.rocmPackages.clr.icd
  ];

  system.stateVersion = "23.11";
}
