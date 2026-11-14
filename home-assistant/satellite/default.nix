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
    networkmanager.ensureProfiles = {
      environmentFiles = [ config.age.secrets.anatidae-quaki-psk.path ];
      profiles.anatidae-quaki = {
        connection = {
          id = "Anatidae Quaki";
          type = "wifi";
        };
        wifi = {
          ssid = "Anatidae Quaki";
          mode = "infrastructure";
          # The AP band-steers clients onto its 5 GHz radio (ch 36), where
          # the Pi's brcmfmac link went deaf after a few minutes while
          # staying associated. A satellite needs a sliver of 2.4 GHz.
          band = "bg";
          # 2 = disable. brcmfmac power saving is the classic cause of a
          # Pi's Wi-Fi going deaf while still associated.
          powersave = 2;
        };
        wifi-security = {
          key-mgmt = "wpa-psk";
          psk = "$ANATIDAE_QUAKI_PSK";
          # 1 = disable. The AP runs WPA2/WPA3 transition mode; since
          # NetworkManager 1.58 a wpa-psk profile also offers SAE, which
          # wpa_supplicant then prefers, and brcmfmac times out every SAE
          # authentication. SAE requires PMF, so this keeps it on WPA2-PSK.
          pmf = 1;
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    };
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

  # The array is flashed with the 1-channel firmware (processed ASR audio
  # only). A replacement unit ships with the 6-channel firmware and needs
  # the same treatment:
  #   sudo respeaker-dfu --download \
  #     $(nix build --print-out-paths .#respeaker-dfu)/share/respeaker/1_channel_firmware.bin
  hardware.respeaker-mic-array = {
    enable = true;
    leds = true;
    # Chip defaults except for these. The base wake word test (Oct 26) failed
    # mostly where music or TV masked the voice, so: deeper suppression of
    # non-stationary noise on the ASR output (default floor 0.3; GAMMA_NN_SR
    # is locked at 1.1 in the 1-channel firmware and ignores writes), a
    # 180 Hz high-pass instead of 70 Hz against music bass and male news
    # voices driving the AGC (wake word models listen at ~300-3000 Hz),
    # and no comfort noise.
    #
    # HPFONOFF: 3 (180 Hz) was the plan, but until Nov 12 the tuning service
    # only ran on boot/replug, so the chip has been on 2 (125 Hz) since Nov 10
    # and all recordings for the wake word retrain are at 2. Stays at 2 until
    # that retrain; then 3, together with the AGC experiment (see "Wake word —
    # Training plan.md").
    tuning = {
      MIN_NN_SR = 0.15;
      HPFONOFF = 2;
      CNIONOFF = 0;
    };
  };

  # Wake word, pipeline, sensitivity, finished-speaking detection and the
  # area are managed on the device page in Home Assistant.
  services.linux-voice-assistant = {
    enable = true;
    name = "satellite-wohnzimmer";
    audioInputDevice = "ReSpeaker";
    audioOutputDevice = "alsa/plughw:CARD=Dummy";
    wakeModel = "okay_computer";
    # Community "computer" models, to compare with okay_nabu (voice ToDo, 4).
    # Own models trained on this room (Nov 12), to replace the stock ones.
    wakeWordDirs = [
      pkgs.ours.computer-wake-words
      pkgs.ours.wohnzimmer-wake-words
    ];
    peripheralApi = true; # for the LED ring and the activation log
    # Send audio in 32 ms chunks (default 64 ms): SRV-VOICE's end-of-speech
    # detection sees the pause sooner. Replay of 414 real commands (Nov 14):
    # 20 ms less waiting (median), same errors.
    extraArgs = [
      "--audio-input-block-size"
      "512"
    ];
    # Every activation with its audio, to judge false and missed wakes.
    activationLog = {
      enable = true;
      audioTarget = "alsa_input.usb-SEEED_ReSpeaker_4_Mic_Array__UAC1.0_-00.mono-fallback";
    };
  };

  # Continuous living room recording (10-minute FLAC files) as training and
  # test material for our own wake word models. Started on Nov 11 as a
  # transient 48 h unit of the same name; this takes over from it (the
  # conflict stops it, a second's gap) and runs until it's removed again
  # or the SD card runs low: ~1.2 GB a day, stops with under 2 GB free.
  # Move the files to hub now and then, then delete them here.
  systemd.services.room-recording-nix = {
    description = "Living room recording for wake word training";
    wantedBy = [ "multi-user.target" ];
    after = [ "pipewire.service" ];
    conflicts = [ "room-recording.service" ];
    path = [
      config.services.pipewire.package
      pkgs.coreutils
    ];
    environment.PIPEWIRE_RUNTIME_DIR = "/run/pipewire";
    script = ''
      while true; do
        if [ "$(df --output=avail -B1M /var/lib/room-recording | tail -1)" -lt 2048 ]; then
          echo "under 2 GB free, stopping"; exit 0
        fi
        f=/var/lib/room-recording/$(date +%Y-%m-%dT%H%M%S.%3N%z).flac
        timeout -s TERM 600 pw-record --target ${config.services.linux-voice-assistant.activationLog.audioTarget} \
          --rate 16000 --channels 1 --format s16 "$f" || [ $? -eq 124 ] || exit 1
      done
    '';
    serviceConfig = {
      User = "lva";
      Group = "lva";
      StateDirectory = "room-recording";
      StateDirectoryMode = "0750";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  # Silent virtual sound card used as LVA's playback sink. Creates ALSA
  # CARD=Dummy. Response audio goes to the Sonos (via tts_relay), not this
  # device: played into the ReSpeaker, the XMOS chip loops it straight back
  # into the capture. The dummy card still paces playback in real time.
  boot.kernelModules = [ "snd-dummy" ];
  # LVA opens the dummy card directly through ALSA; keep WirePlumber off it.
  services.pipewire.wireplumber.extraConfig."51-dummy-ignore"."monitor.alsa.rules" = [
    {
      matches = [ { "device.name" = "~alsa_card.platform-snd_dummy.*"; } ];
      actions.update-props."device.disabled" = true;
    }
  ];

  nvim.enable = true;

  age.secrets.anatidae-quaki-psk.rekeyFile = secrets.anatidae-quaki-psk;
}
