{ pkgs, ... }:
{
  _module.args.defaultUser = "charlotte";
  imports =
    [
      ./hardware-configuration.nix

      ../common/global

      ../common/optional/bluetooth.nix
      ../common/optional/cups.nix
      ../common/optional/dconf.nix
      ../common/optional/greetd.nix
      ../common/optional/nvim.nix
      ../common/optional/pipewire.nix
      ../common/optional/surfshark.nix
      ../common/optional/suspend.nix
      ../common/optional/wifi.nix
      ../common/optional/zsh.nix

      ../../users/charlotte/user.nix
    ];

  enableNas = true;
  enableNasBackup = true;

  environment.systemPackages = [ pkgs.ntfs3g ];
  fileSystems."/media/Media" = {
    device = "/dev/disk/by-uuid/A01C13B21C138288";
    fsType = "ntfs-3g";
    label = "Media";
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

  boot.initrd.kernelModules = [ "amdgpu" "usb_storage" ];
  boot.kernelParams = [ "video=DP-2:2560x1440@59.91" "video=DP-3:2560x1440@59.91" ];

  networking.networkmanager.enable = true;
  networking.hostName = "hub";
  networking.nameservers = [ "192.168.30.13" ];

  hardware.opengl.enable = true;
  hardware.opengl.extraPackages = [ pkgs.amdvlk ];

  system.stateVersion = "23.11";
}
