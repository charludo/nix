{ pkgs, inputs, outputs, ... }:
{
  _module.args.defaultUser = "charlotte";
  imports =
    [
      inputs.nix-flatpak.nixosModules.nix-flatpak

      ./hardware-configuration.nix
      ../common/optional/vmify.nix

      ../common/global

      ../common/optional/bluetooth.nix
      ../common/optional/cups.nix
      ../common/optional/dconf.nix
      ../common/optional/fish.nix
      ../common/optional/fontconfig.nix
      ../common/optional/greetd.nix
      ../common/optional/gvfs.nix
      ../common/optional/nvim.nix
      ../common/optional/pipewire.nix
      ../common/optional/screensharing.nix
      ../common/optional/steam-firewall.nix
      ../common/optional/surfshark.nix
      ../common/optional/suspend.nix
      ../common/optional/wifi.nix

      ../../users/charlotte/user.nix
    ];

  enableNas = true;

  fileSystems."/media/Media" = {
    device = "/dev/disk/by-uuid/A01C13B21C138288";
    fsType = "ntfs-3g";
  };

  # boot.kernelPackages = pkgs.linuxPackages_6_1;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    devices = [ "nodev" ];
    useOSProber = true;

    extraEntries = ''
      menuentry "Hub" {
          set root=(hd2,1)
          chainloader /EFI/NixOS-boot/grubx64.efi
      }
    '';
    extraEntriesBeforeNixOS = true;
  };

  boot.initrd.kernelModules = [ "amdgpu" "usb_storage" ];
  boot.kernelParams = [ "video=DP-2:2560x1440@59.91" "video=DP-3:2560x1440@59.91" ];

  networking.networkmanager.enable = true;
  networking.hostName = "excession";
  networking.nameservers = [ "192.168.30.13" ];
  networking.firewall = {
    allowedTCPPorts = [ 80 443 4380 ];
    allowedTCPPortRanges = [
      # Steam
      { from = 27000; to = 27050; }

      # ESO
      { from = 24100; to = 24131; }
      { from = 24300; to = 24331; }
      { from = 24500; to = 24507; }
    ];
    allowedUDPPortRanges = [
      # Steam
      { from = 27000; to = 27050; }

      # ESO
      { from = 24100; to = 24131; }
      { from = 24300; to = 24331; }
      { from = 24500; to = 24507; }

      # Stellaris
      { from = 17780; to = 17785; }
    ];
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = [ pkgs.amdvlk pkgs.rocmPackages.clr.icd pkgs.mesa.drivers ];
    extraPackages32 = [ pkgs.driversi686Linux.amdvlk ];
  };

  services.xserver = {
    enable = true;
    videoDrivers = [ "amdgpu" ];
  };
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  programs.steam = {
    enable = true;
    extest.enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;

    package = pkgs.steam.override {
      extraPkgs = pkgs: with pkgs; [
        xorg.libXcursor
        xorg.libXi
        xorg.libXinerama
        xorg.libXScrnSaver
        libpng
        libpulseaudio
        libvorbis
        stdenv.cc.cc.lib
        libkrb5
        keyutils
      ];
    };
  };
  programs.gamemode.enable = true;
  programs.gamescope.enable = true;

  environment.systemPackages = with pkgs; [
    ntfs3g
    mangohud
    protonup
    lutris
    bottles
    wine
  ];
  environment.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATH =
      "/home/charlotte/.steam/root/compatibilitytools.d";
  };

  services.flatpak.enable = true;
  services.flatpak.packages = [
    "gg.minion.Minion"
  ];
  system.stateVersion = "23.11";
}
