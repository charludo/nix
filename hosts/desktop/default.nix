{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../common
    ../../users/marie/user.nix
  ];
  nas.enable = true;
  nas.backup.enable = true;

  age.enable = true;
  graphicalFixes.enable = true;
  nicerFonts.enable = true;
  printers.enable = true;
  soundConfig.enable = true;
  steamOpenFirewall.enable = true;
  wifi.enable = true;
  programs.dconf.enable = true;

  fileSystems."/run/media/marie/Storage" = {
    device = "/dev/disk/by-uuid/00D46466D4645FC0";
    fsType = "ntfs-3g";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "desktop";
  networking.networkmanager.enable = true;

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "intl";
  };
  services.xrdp = {
    enable = true;
    audio.enable = true;
    defaultWindowManager = "startplasma-x11";
    openFirewall = true;
  };

  programs.steam = {
    enable = true;
    extest.enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };
  programs.gamescope.enable = true;
  programs.gamemode.enable = true;
  # programs.gamemode.settings = {
  #   general = {
  #     renice = 10;
  #   };
  #
  #   gpu = {
  #     apply_gpu_optimisations = "accept-responsibility";
  #     gpu_device = 1;
  #     gpu_vendor = "nvidia";
  #   };
  # };
  powerManagement.cpuFreqGovernor = "performance";

  users.mutableUsers = lib.mkForce true;

  environment.systemPackages = with pkgs; [
    ntfs3g
    mangohud
    protonup-rs

    (pkgs.symlinkJoin {
      name = "beyond-all-reason";
      paths = [ pkgs.beyond-all-reason ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/beyond-all-reason \
          --set DRI_PRIME 10de:2786 \
          --set __NV_PRIME_RENDER_OFFLOAD 1 \
          --set __GLX_VENDOR_LIBRARY_NAME nvidia
      '';
    })
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.beta;
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
  };

  system.stateVersion = "25.11";
}
