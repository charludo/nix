{
  config,
  pkgs,
  private-settings,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../common
    ../../users/charlotte/user.nix
  ];

  age.enable = true;
  # androidUtils.enable = true;
  # ausweisapp.enable = true;
  bluetooth.enable = true;
  # eid.enable = true;
  graphicalFixes.enable = true;
  greetd.enable = true;
  gvfs.enable = true;
  ld.enable = true;
  nicerFonts.enable = true;
  nvim.enable = true;
  # onlykey.enable = true;
  printers.enable = true;
  screensharing.enable = true;
  soundConfig.enable = true;
  surfshark.enable = true;
  suspend.enable = true;
  suspend.gigabyteFix = true;
  tailscale.enable = true;
  wifi.enable = true;
  wyomingSatellite.enable = true;
  wyomingSatellite.leds.enable = true;
  wyomingSatellite.leds.brightness = 12;
  wyomingSatellite.tuning = {
    # --- Acoustic echo handling -------------------------------------------
    # Linear AEC: cancels the played-back TTS so we don't hear ourselves.
    ECHOONOFF = 1;
    # Non-linear echo attenuation: catches residual echo after the linear AEC.
    NLATTENONOFF = 1;
    # Short transient echo suppression.
    TRANSIENTONOFF = 1;
    # Estimate room reverb time so the AES adapts to the actual acoustics.
    RT60ONOFF = 1;

    # --- Automatic gain control ------------------------------------------
    AGCONOFF = 1;
    AGCMAXGAIN = 30.0;        # up to ~30 dB; needed for far-field speakers
    AGCDESIREDLEVEL = 0.03;   # ≈ -15 dBov target
    AGCTIME = 1.0;            # 1 s ramp (chip max). Prevents pumping during
                              # natural pauses; faster ramps confuse ASR.

    # --- High-pass filter -------------------------------------------------
    # 180 Hz: more aggressive rumble removal. Safe here because the lowest
    # female fundamentals (~165-200 Hz) lose only the fundamental itself —
    # ASR relies on formants/harmonics well above that, so intelligibility
    # is unaffected.
    HPFONOFF = 3;

    # --- Noise suppression -----------------------------------------------
    # Keep stationary + non-stationary on, but raise the ASR-path gain
    # floors so we don't carve out speech transients. Default floors are
    # -16 dB / -10 dB; we raise them to ~-10 dB / -8 dB. ASR / wake-word
    # models tolerate background noise better than over-processed audio.
    STATNOISEONOFF = 1;
    STATNOISEONOFF_SR = 1;
    NONSTATNOISEONOFF = 1;
    NONSTATNOISEONOFF_SR = 1;
    MIN_NS_SR = 0.3;          # -10 dB floor (vs default 0.15 = -16 dB)
    MIN_NN_SR = 0.4;          # -8 dB floor (vs default 0.3 = -10 dB)

    # --- Comfort noise ---------------------------------------------------
    # Off for ASR — don't inject synthetic noise into silence.
    CNIONOFF = 0;
  };
  programs.dconf.enable = true;

  age.secrets.yubikey-sudo.rekeyFile = private-settings.yubikeys.zakalwe.sudoFile;

  nas.enable = true;
  nas.backup.enable = true;
  # nas.qnap.enable = true;

  rsync."media" = {
    tasks = [
      {
        from = "/media/Media";
        to = "${config.nas.location}/CloudSync/Media";
      }
    ];
    timerConfig = {
      OnBootSec = "30min";
      OnUnitActiveSec = "1h";
    };
    requires = [
      "media-Media.mount"
      "media-NAS.mount"
    ];
  };

  environment.systemPackages = [ pkgs.ntfs3g ];
  fileSystems."/media/Media" = {
    device = "/dev/disk/by-uuid/A01C13B21C138288";
    fsType = "ntfs-3g";
  };

  boot.initrd.luks.devices = {
    # /
    "luks-19d023d9-885a-4f40-b03c-775d6ec49388" = {
      device = "/dev/disk/by-uuid/19d023d9-885a-4f40-b03c-775d6ec49388";
      keyFile = "/dev/disk/by-id/usb-Intenso_Micro_Line_6414041056097521862-0:0";
      keyFileSize = 4096;
      bypassWorkqueues = true;
    };
    # swap
    "luks-1d6679b1-71d2-4ed8-8a84-44a28c388a3f" = {
      device = "/dev/disk/by-uuid/1d6679b1-71d2-4ed8-8a84-44a28c388a3f";
      keyFile = "/dev/disk/by-id/usb-Intenso_Micro_Line_6414041056097521862-0:0";
      keyFileSize = 4096;
      bypassWorkqueues = true;
    };
  };

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    devices = [ "nodev" ];
    useOSProber = false;

    extraEntries = ''
      menuentry "Excession" {
          set root=(hd3,1)
          chainloader /EFI/NixOS-boot/grubx64.efi
      }
    '';
    extraEntriesBeforeNixOS = false;
  };

  boot.initrd.kernelModules = [ "usb_storage" ];
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
    pkgs.rocmPackages.clr.icd
  ];

  hardware.amdgpu = {
    initrd.enable = true;
    opencl.enable = true;
  };
}
