{
  config,
  pkgs,
  secrets,
  ...
}:
{
  networking = {
    # This is a bit awkward. When generating the SD card, use this instead of the stuff below.
    # wireless = {
    # enable = true;
    # interfaces = [ "wlan0" ];
    # networks."Anatidae Quaki".psk = "...";
    # };

    # After getting the correct pubkey and agenix rekeying, enable this instead.
    networkmanager.enable = true;
    timeServers = [ "192.168.24.1" ];
  };

  snow = {
    useRemoteSudo = true;
    askSudoPassword = false;
    tags = [ "stateless" ];
    buildHost = "gsv";
    targetHost = config.networking.hostName;
  };

  console.enable = false;
  hardware.enableRedistributableFirmware = true;
  environment.systemPackages = with pkgs; [
    libraspberrypi
    raspberrypi-eeprom
  ];

  sdImage.compressImage = false;
  boot.supportedFilesystems.zfs = pkgs.lib.mkForce false;

  wyomingSatellite = {
    enable = true;
    wakeWordThreshold = 0.6;
    customWakeWordModel = ../assets/wakewords/computer_v2.tflite;

    leds.enable = true;
    leds.brightness = 12;

    tuning = {
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
      AGCMAXGAIN = 30.0; # up to ~30 dB; needed for far-field speakers
      AGCDESIREDLEVEL = 0.03; # ≈ -15 dBov target
      AGCTIME = 1.0;
      # 1 s ramp (chip max). Prevents pumping during
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
      MIN_NS_SR = 0.3; # -10 dB floor (vs default 0.15 = -16 dB)
      MIN_NN_SR = 0.4; # -8 dB floor (vs default 0.3 = -10 dB)

      # --- Comfort noise ---------------------------------------------------
      # Off for ASR — don't inject synthetic noise into silence.
      CNIONOFF = 0;
    };
  };

  nvim.enable = true;

  age.secrets.anatidae-quaki.rekeyFile = secrets.wifi-anatidae-quaki;
  environment.etc."NetworkManager/system-connections/Anatidae Quaki.nmconnection" = {
    source = "${config.age.secrets.anatidae-quaki.path}";
  };
}
