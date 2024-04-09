{ pkgs, ... }:
{
  _module.args.defaultUser = "charlotte";
  imports =
    [
      ./hardware-configuration.nix

      ../common/global

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

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    devices = [ "nodev" ];
    configurationLimit = 5;
    useOSProber = true;
  };

  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelParams = [ "video=DP-2:2560x1440@59.91" "video=DP-3:2560x1440@59.91" ];

  networking.networkmanager.enable = true;
  networking.hostName = "hub";
  networking.nameservers = [ "192.168.30.5" "192.168.30.13" "1.1.1.1" ];

  hardware.opengl.enable = true;
  hardware.opengl.extraPackages = [ pkgs.amdvlk ];

  system.stateVersion = "23.11";
}
