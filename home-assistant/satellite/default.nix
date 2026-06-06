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
    # Slight tightening (0.5 → 0.55). Cleaner audio from the tuning below
    # raises real-wake confidence enough to absorb this, while cutting the
    # false-wake rate in the larger / noisier living room.
    wakeWordThreshold = 0.55;
    customWakeWordModel = ../assets/wakewords/computer_v2.tflite;

    leds.enable = true;
    leds.brightness = 12;

    # XMOS XVF-3000 DSP parameters. All writable parameters are listed
    # explicitly with their chip defaults; values we deliberately diverge
    # from default are flagged in comments. See the XVF-3000 datasheet for
    # the underlying ranges and semantics.
    tuning = {
      # ===== Acoustic Echo Cancellation ===================================

      # Adaptive Echo Canceler updates inhibit.
      # 0 = adaptation enabled, 1 = freeze (filter only). Default: 0.
      AECFREEZEONOFF = 0;

      # Limit on norm of AEC filter coefficients. Range [0.25 .. 16].
      # Chip default: 0.25.
      AECNORM = 0.25;

      # Threshold for far-end signal detection in AEC, linear power.
      # Range [1e-09 .. 1]. Default: 1e-08 (= -80 dBov).
      AECSILENCELEVEL = 1.0e-08;

      # Echo suppression. 0 = OFF, 1 = ON. Default: 0.
      # ON: cancels the played-back TTS so we don't hear ourselves.
      ECHOONOFF = 1;

      # Over-subtraction factor of echo (direct + early). Range [0 .. 3].
      GAMMA_E = 1.0;

      # Over-subtraction factor of echo tail. Range [0 .. 3].
      GAMMA_ETAIL = 1.0;

      # Over-subtraction factor of non-linear echo. Range [0 .. 5].
      GAMMA_ENL = 1.0;

      # Non-linear echo attenuation. 0 = OFF, 1 = ON. Default: 0.
      # ON: catches residual echo after the linear AEC.
      NLATTENONOFF = 1;

      # Non-Linear AEC training mode.
      # 0 = OFF, 1 = phase 1, 2 = phase 2. Default: 0.
      NLAEC_MODE = 0;

      # Short transient echo suppression. 0 = OFF, 1 = ON. Default: 0.
      TRANSIENTONOFF = 1;

      # ===== Reverb estimation ============================================

      # RT60 estimation for the AES. 0 = OFF, 1 = ON. Default: 0.
      # ON so the AES adapts to actual room acoustics (matters more in
      # the more reverberant living room).
      RT60ONOFF = 1;

      # ===== High-pass filter =============================================

      # HPF on microphone signals.
      # 0 = OFF, 1 = 70 Hz, 2 = 125 Hz, 3 = 180 Hz. Default: 0.
      # 180 Hz: aggressive rumble removal. Safe for ASR — only the lowest
      # female fundamentals (~165-200 Hz) lose their fundamental tone;
      # formants/harmonics above that carry intelligibility.
      HPFONOFF = 3;

      # ===== Beamformer ===================================================

      # Adaptive beamformer updates.
      # 0 = adaptation enabled, 1 = freeze (filter only). Default: 0.
      FREEZEONOFF = 0;

      # ===== Automatic Gain Control =======================================

      # AGC. 0 = OFF, 1 = ON. Default: 0.
      AGCONOFF = 1;

      # Maximum AGC gain factor (linear). Range [1 .. 1000] = [0 .. 60] dB.
      # Chip default: 31.6 (= 30 dB).
      # 100 (= 40 dB) to extend far-field reach in the new room.
      AGCMAXGAIN = 100.0;

      # Target output power level (linear). Range [1e-08 .. 0.99].
      # Chip default: 0.005 (= -23 dBov).
      # 0.05 (≈ -13 dBov) gives the wake-word model a hotter signal.
      AGCDESIREDLEVEL = 0.05;

      # Ramp up/down time constant in seconds. Range [0.1 .. 1.0].
      # 1 s (chip max) prevents pumping during natural pauses; faster
      # ramps confuse ASR.
      AGCTIME = 1.0;

      # ===== Stationary noise suppression (microphone path) ===============

      # 0 = OFF, 1 = ON. Default: 0.
      STATNOISEONOFF = 1;

      # Over-subtraction factor. Range [0 .. 3]. Chip default: 1.0.
      GAMMA_NS = 1.0;

      # Gain floor for stationary NS. Default: 0.15 (= -16 dB).
      MIN_NS = 0.15;

      # ===== Non-stationary noise suppression (microphone path) ===========

      # 0 = OFF, 1 = ON. Default: 0.
      NONSTATNOISEONOFF = 1;

      # Over-subtraction factor. Range [0 .. 3]. Chip default: 1.1.
      GAMMA_NN = 1.1;

      # Gain floor for non-stationary NS. Default: 0.3 (= -10 dB).
      MIN_NN = 0.3;

      # ===== Stationary noise suppression (ASR path) ======================

      # 0 = OFF, 1 = ON. Default: 0.
      STATNOISEONOFF_SR = 1;

      # Over-subtraction factor for ASR path. Default: 1.0.
      GAMMA_NS_SR = 1.0;

      # Gain floor for stationary NS on ASR path. Default: 0.15 (-16 dB).
      # Back to chip default (was 0.3 / -10 dB). In the noisier room, the
      # extra suppression headroom is worth more than transient fidelity.
      MIN_NS_SR = 0.15;

      # ===== Non-stationary noise suppression (ASR path) ==================

      # 0 = OFF, 1 = ON. Default: 0.
      NONSTATNOISEONOFF_SR = 1;

      # Over-subtraction factor for ASR path. Default: 1.1.
      GAMMA_NN_SR = 1.1;

      # Gain floor for non-stationary NS on ASR path.
      # Default: 0.3 (-10 dB). Back to default (was 0.4 / -8 dB).
      MIN_NN_SR = 0.3;

      # ===== Chip-internal voice activity detection =======================

      # Threshold for the chip's internal VAD (drives AGC etc.).
      # Range [-inf .. 60] dB. Default: 1.5 (= 3.5 dB).
      GAMMAVAD_SR = 1.5;

      # ===== Comfort noise ================================================

      # Comfort Noise Insertion. 0 = OFF, 1 = ON. Default: 0.
      # OFF for ASR — don't inject synthetic noise into silence.
      CNIONOFF = 0;
    };
  };


  nvim.enable = true;

  age.secrets.anatidae-quaki.rekeyFile = secrets.wifi-anatidae-quaki;
  environment.etc."NetworkManager/system-connections/Anatidae Quaki.nmconnection" = {
    source = "${config.age.secrets.anatidae-quaki.path}";
  };
}
