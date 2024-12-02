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

  # Silent virtual sound card used as wyoming's playback sink (see
  # wyomingSatellite.soundDevice below). Creates ALSA CARD=Dummy.
  boot.kernelModules = [ "snd-dummy" ];

  wyomingSatellite = {
    enable = true;
    area = "Wohnzimmer";
    # wakeWord = "alexa";
    wakeWordThreshold = 0.5;
    customWakeWordModel = ../assets/wakewords/computer_v2.tflite;

    leds.enable = true;
    leds.brightness = 12;

    # Response audio goes to the Sonos (via tts-relay), not this device. If
    # wyoming plays TTS into the ReSpeaker, the XMOS chip loops it straight
    # back into the capture (audible on the monitor tap even with no speaker
    # attached). Send playback to a silent snd-dummy card instead — it still
    # paces in real time, so the LED ring's speak animation lasts the whole
    # response.
    soundDevice = "plughw:CARD=Dummy";

    # Live-listen to the exact post-DSP audio the satellite hears. The
    # satellite's VLAN blocks it from reaching out, so we pull over SSH
    # instead: the audio is tee'd to a localhost socket and rides back over
    # the SSH session you open. From a machine that can SSH in:
    #   ssh <this-host> wyoming-mic-tap \
    #     | ffplay -nodisp -f s16le -ar 16000 -ch_layout mono -
    monitor.enable = true;
    monitor.mode = "pull";

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
      HPFONOFF = 2;

      # ===== Beamformer ===================================================

      # Adaptive beamformer updates.
      # 0 = adaptation enabled, 1 = freeze (filter only). Default: 0.
      FREEZEONOFF = 0;

      # ===== Automatic Gain Control =======================================

      # AGC. 0 = OFF, 1 = ON. Default: 0.
      # OFF: AGC scales voice and noise together, so it can't lift far-field
      # voice out of the noise floor — it only shifts the absolute level. We
      # run fixed-gain for predictable behaviour and let the wake-word model
      # and HA's VAD work on the unmodified signal.
      AGCONOFF = 0;

      # Maximum AGC gain factor (linear). Range [1 .. 1000] = [0 .. 60] dB.
      # Chip default: 31.6 (= 30 dB). Inert while AGCONOFF = 0; kept at the
      # default so it's sane if AGC is ever re-enabled.
      AGCMAXGAIN = 31.6;

      # Target output power level (linear). Range [1e-08 .. 0.99].
      # Chip default: 0.005 (= -23 dBov). Inert while AGCONOFF = 0.
      AGCDESIREDLEVEL = 0.01;

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
      # 0.9 (≈ -0.9 dB): effectively almost no flooring on this (comms) path.
      MIN_NS = 0.9;

      # ===== Non-stationary noise suppression (microphone path) ===========

      # 0 = OFF, 1 = ON. Default: 0.
      NONSTATNOISEONOFF = 1;

      # Over-subtraction factor. Range [0 .. 3]. Chip default: 1.1.
      GAMMA_NN = 2.1;

      # Gain floor for non-stationary NS. Default: 0.3 (= -10 dB).
      MIN_NN = 0.1;

      # ===== Stationary noise suppression (ASR path) ======================

      # 0 = OFF, 1 = ON. Default: 0.
      STATNOISEONOFF_SR = 1;

      # Over-subtraction factor for ASR path. Range [0 .. 3]. Default: 1.0.
      # 3.0 (max): aggressive stationary-noise subtraction on the ASR path.
      GAMMA_NS_SR = 3.0;

      # Gain floor for stationary NS on ASR path. Default: 0.15 (-16 dB).
      # 0.1 (-20 dB) deepens silence so HA's server-side VAD trips faster
      # and the chip's residual noise floor doesn't reach the wake model.
      MIN_NS_SR = 0.1;

      # ===== Non-stationary noise suppression (ASR path) ==================

      # 0 = OFF, 1 = ON. Default: 0.
      NONSTATNOISEONOFF_SR = 1;

      # Over-subtraction factor for ASR path. Range [0 .. 3]. Default: 1.1.
      # 3.0 (max): aggressive transient-noise subtraction on the ASR path.
      GAMMA_NN_SR = 3.0;

      # Gain floor for non-stationary NS on ASR path.
      # Default: 0.3 (-10 dB). 0.1 (-20 dB) for quieter silence between
      # words and fewer false "still speaking" reads by the server VAD.
      MIN_NN_SR = 0.1;

      # ===== Chip-internal voice activity detection =======================

      # Threshold for the chip's internal VAD (drives AGC etc.).
      # Range [-inf .. 60] dB. Default: 1.5 (= 3.5 dB). 3.5 linear (≈ 11 dB)
      # makes the gate stricter so low-level background isn't treated as
      # voice. (Mostly relevant only if AGC is re-enabled.)
      GAMMAVAD_SR = 3.5;

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
