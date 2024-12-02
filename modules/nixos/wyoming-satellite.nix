{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.wyomingSatellite;

  # The ReSpeaker Mic Array v2.0 (XVF-3000) exposes a multi-channel stream:
  # channel 0 is the processed ASR output (AEC + AGC + NS + beamforming),
  # channels 1..N-2 are the raw mics, and the last channel is the playback
  # reference. Asking ALSA for one channel via `plughw -c 1` *averages* all
  # of them, which buries the processed channel under the raw mics and the
  # playback reference (you'd literally hear the TTS). So we capture every
  # channel and use sox to pass only the processed one to wyoming.
  arecord = lib.getExe' pkgs.alsa-utils "arecord";
  sox = lib.getExe pkgs.sox;
  captureScript = pkgs.writeShellScript "wyoming-capture" ''
    ${arecord} -D ${cfg.alsaDevice} -r 16000 -c ${toString cfg.captureChannels} -f S16_LE -t raw \
      | ${sox} -t raw -r 16000 -e signed-integer -b 16 -c ${toString cfg.captureChannels} - \
               -t raw -r 16000 -e signed-integer -b 16 -c 1 - remix ${toString cfg.processedChannel}
  '';

  socat = lib.getExe' pkgs.socat "socat";

  # Where the tee'd copy of the post-DSP stream goes:
  #   pull: a localhost UDP socket. Nothing leaves the box; you SSH in and
  #         run `wyoming-mic-tap` to pull it. Works through VLAN isolation
  #         because the audio rides the SSH session you initiate.
  #   push: UDP datagrams onto the network for a same-L2 listener.
  # Either way socat uses connectionless sendto, so the capture is never
  # blocked even when no one is listening.
  monitorSink =
    if cfg.monitor.mode == "pull" then
      "UDP-SENDTO:127.0.0.1:${toString cfg.monitor.port}"
    else
      "UDP-DATAGRAM:${cfg.monitor.address}:${toString cfg.monitor.port},broadcast";

  # When monitoring is enabled, tee a copy of the (already channel-extracted)
  # capture to the monitor sink while the original still flows to stdout for
  # wyoming, so the monitor is faithful to what wyoming actually hears.
  micMonitorScript = pkgs.writeShellScript "wyoming-mic-monitor" ''
    ${captureScript} \
      | ${lib.getExe' pkgs.coreutils "tee"} >(${socat} -u - ${monitorSink} 2>/dev/null)
  '';

  micCommand = if cfg.monitor.enable then "${micMonitorScript}" else "${captureScript}";

  # Helper placed on PATH for pull mode: reads the localhost feed and writes
  # raw audio to stdout, so you can `ssh <sat> wyoming-mic-tap | <player>`.
  micTap = pkgs.writeShellScriptBin "wyoming-mic-tap" ''
    exec ${socat} -u UDP-RECV:${toString cfg.monitor.port},reuseaddr -
  '';
in
{
  options.wyomingSatellite = {
    enable = lib.mkEnableOption "Wyoming satellite for Home Assistant";

    alsaDevice = lib.mkOption {
      type = lib.types.str;
      default = "plughw:CARD=ArrayUAC10,DEV=0";
      description = "ALSA device used for capture (and, by default, playback)";
    };

    soundDevice = lib.mkOption {
      type = lib.types.str;
      default = cfg.alsaDevice;
      defaultText = lib.literalExpression "config.wyomingSatellite.alsaDevice";
      description = ''
        ALSA device wyoming plays TTS/response audio to. Defaults to
        alsaDevice. Point it elsewhere when response audio is routed to
        another speaker (e.g. a Sonos): playing into the capture device
        makes the XMOS chip loop that audio straight back into the
        recording. A snd-dummy card ("plughw:CARD=Dummy") is a good silent
        sink that still paces playback in real time, so the LED ring's
        speak animation lasts for the whole response.
      '';
    };

    captureChannels = lib.mkOption {
      type = lib.types.ints.positive;
      default = 6;
      description = ''
        Number of channels the capture device exposes. The ReSpeaker Mic
        Array v2.0 (XVF-3000) 6-channel firmware presents 6: channel 0 is
        the processed ASR output, channels 1-4 the raw mics, channel 5 the
        playback reference. We capture all of them and keep only
        processedChannel, so the processed signal isn't averaged away.
      '';
    };

    processedChannel = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
      description = ''
        Which channel to hand to wyoming, as a 1-based sox remix index
        (1 = the device's channel 0, the processed ASR output). Audition
        the channels with `arecord -c N … | sox … remix <n>` if your unit's
        layout differs.
      '';
    };

    name = lib.mkOption {
      type = lib.types.str;
      default = "${config.networking.hostName}-satellite";
      description = "Satellite name advertised to Home Assistant";
    };

    area = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "HA area name this satellite belongs to; used by Assist to scope intent resolution (e.g. \"Wohnzimmer\")";
    };

    wakeWord = lib.mkOption {
      type = lib.types.str;
      default = "computer";
      description = "Wake word model name handled by wyoming-openwakeword";
    };

    wakeWordThreshold = lib.mkOption {
      type = lib.types.numbers.between 0.0 1.0;
      default = 0.6;
      description = "Detection threshold for wyoming-openwakeword (0.0..1.0); raise to reduce false wakes, lower to catch quieter triggers";
    };

    customWakeWordModel = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional path to a `.tflite` custom wake-word model";
    };

    leds = {
      enable = lib.mkEnableOption "ReSpeaker LED ring driven by wyoming events";

      brightness = lib.mkOption {
        type = lib.types.nullOr (lib.types.ints.between 0 31);
        default = null;
        description = "LED ring brightness 0..31 or null for device default";
      };

      notificationPort = lib.mkOption {
        type = lib.types.port;
        default = 10750;
        description = "TCP port for the HTTP notification API";
      };

      openNotificationFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open the notification port in the firewall";
      };

      debug = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable debug logging in the LED bridge";
      };
    };

    monitor = {
      enable = lib.mkEnableOption ''
        live monitoring of the post-DSP microphone stream. When on, the
        microphone command tees a copy of the exact audio wyoming-satellite
        receives (i.e. after the ReSpeaker XMOS DSP: AEC, AGC, noise
        suppression, beamforming) so you can listen to it live. Off by
        default so normal operation is never affected. See monitor.mode for
        how to listen
      '';

      mode = lib.mkOption {
        type = lib.types.enum [
          "pull"
          "push"
        ];
        default = "pull";
        description = ''
          How to reach the monitor stream.

          "pull" (default): the copy is tee'd to a localhost UDP socket and
          never leaves the box. Listen by SSHing into the satellite and
          piping the `wyoming-mic-tap` helper into a local player, e.g. from
          your workstation:
            ssh <satellite> wyoming-mic-tap \
              | ffplay -nodisp -f s16le -ar 16000 -ch_layout mono -
          This works even when the satellite's VLAN forbids it from
          initiating connections outward, since the audio rides back over
          the SSH session you opened.

          "push": the copy is streamed as UDP datagrams to
          monitor.address:monitor.port for a listener on the same L2
          segment. Requires the satellite to be able to reach the listener,
          so it will not cross an isolating VLAN boundary. Listen on the
          target machine with:
            ffplay -nodisp -f s16le -ar 16000 -ch_layout mono "udp://@:<port>"
        '';
      };

      address = lib.mkOption {
        type = lib.types.str;
        default = "192.168.50.118";
        description = ''
          Destination for the monitor stream in "push" mode (ignored in
          "pull" mode). A multicast group lets any machine on the LAN
          subscribe without the satellite knowing the listener; set a
          unicast IP for a single listener.
        '';
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 12345;
        description = "UDP port for the monitor stream";
      };
    };

    debugRecordingDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/var/lib/wyoming-satellite/recordings";
      description = ''
        If set, passes --debug-recording-dir to wyoming-satellite, which
        writes WAV files of the audio it actually processed (i.e. after its
        own pipeline, the closest thing to "what the satellite sent on").
        This is file-based, not live — pair it with monitor.enable for live
        listening. The directory is created and owned by the service user.
      '';
    };

    tuning = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.oneOf [
          lib.types.int
          lib.types.float
        ]
      );
      default = { };
      example = {
        AGCONOFF = 1;
        AGCMAXGAIN = 30.0;
        AGCDESIREDLEVEL = 0.03;
        HPFONOFF = 2;
        STATNOISEONOFF = 1;
        NONSTATNOISEONOFF = 1;
        ECHOONOFF = 1;
      };
      description = "XMOS XVF-3000 DSP parameters to apply at boot via the ReSpeaker's USB tuning interface";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      [
        pkgs.alsa-utils # arecord/aplay for ad-hoc capture debugging over SSH
        pkgs.sox # play/remix for auditioning individual mic channels
      ]
      ++ lib.optional (cfg.monitor.enable && cfg.monitor.mode == "pull") micTap;

    users.users.wyoming-satellite = {
      isSystemUser = true;
      group = "wyoming-satellite";
      extraGroups = [ "audio" ];
      description = "Wyoming Satellite";
    };
    users.groups.wyoming-satellite = { };

    services.wyoming.openwakeword = {
      enable = true;
      uri = "tcp://127.0.0.1:10400";
      threshold = cfg.wakeWordThreshold;
      customModelsDirectories = lib.optional (cfg.customWakeWordModel != null) (
        pkgs.runCommand "wyoming-custom-wakeword" { } ''
          mkdir -p $out
          cp ${cfg.customWakeWordModel} $out/${baseNameOf (toString cfg.customWakeWordModel)}
        ''
      );
    };

    services.wyoming.satellite = {
      enable = true;
      user = "wyoming-satellite";
      group = "wyoming-satellite";
      inherit (cfg) name;
      area = lib.mkIf (cfg.area != null) cfg.area;
      uri = "tcp://0.0.0.0:10700";

      microphone.command = micCommand;
      sound.command = "${lib.getExe' pkgs.alsa-utils "aplay"} -D ${cfg.soundDevice} -r 22050 -c 1 -f S16_LE -t raw";
      microphone.autoGain = 0;
      vad.enable = false;

      extraArgs = [
        "--wake-uri"
        "tcp://127.0.0.1:10400"
        "--wake-word-name"
        cfg.wakeWord
      ]
      ++ lib.optionals (cfg.debugRecordingDir != null) [
        "--debug-recording-dir"
        cfg.debugRecordingDir
      ]
      ++ lib.optionals cfg.leds.enable [
        "--event-uri"
        "unix:///run/wyoming-satellite/events.sock"
      ];
    };

    systemd.tmpfiles.rules = lib.mkIf (cfg.debugRecordingDir != null) [
      "d ${cfg.debugRecordingDir} 0750 wyoming-satellite wyoming-satellite -"
    ];

    systemd.services.wyoming-satellite = {
      serviceConfig = {
        PrivateDevices = lib.mkForce false;
        DeviceAllow = lib.mkForce [ "char-alsa rw" ];
        DevicePolicy = lib.mkForce "closed";
        Restart = lib.mkForce "on-failure";
        RestartSec = 5;
        StartLimitBurst = 30;
      }
      // lib.optionalAttrs (cfg.debugRecordingDir != null) {
        ReadWritePaths = [ cfg.debugRecordingDir ];
      };
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ] ++ lib.optional cfg.leds.enable "respeaker-led-bridge.service";
      requires = lib.mkIf cfg.leds.enable [ "respeaker-led-bridge.service" ];
    };

    networking.firewall.allowedTCPPorts = [
      10700
    ]
    ++ lib.optionals (cfg.leds.enable && cfg.leds.openNotificationFirewall) [
      cfg.leds.notificationPort
    ];

    services.pipewire.wireplumber.extraConfig."51-respeaker-ignore" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            { "device.name" = "~alsa_card.usb-SEEED_ReSpeaker.*"; }
          ];
          actions.update-props."device.disabled" = true;
        }
      ];
    };

    services.udev.extraRules = lib.mkIf (cfg.leds.enable || cfg.tuning != { }) ''
      SUBSYSTEM=="usb", ATTR{idVendor}=="2886", ATTR{idProduct}=="0018", MODE="0660", GROUP="wyoming-satellite"
    '';

    systemd.services.respeaker-tuning-apply = lib.mkIf (cfg.tuning != { }) {
      description = "Apply ReSpeaker XMOS DSP tuning parameters";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-udev-settle.service" ];
      wants = [ "systemd-udev-settle.service" ];
      bindsTo = [ "dev-bus-usb.device" ];
      serviceConfig = {
        Type = "oneshot";
        User = "wyoming-satellite";
        Group = "wyoming-satellite";
        ExecStart = "${lib.getExe' pkgs.ours.respeaker-led-bridge "respeaker-tuning-apply"} ${pkgs.writeText "respeaker-tuning.json" (builtins.toJSON cfg.tuning)}";
        Restart = "on-failure";
        RestartSec = 2;
        StartLimitBurst = 5;
      };
    };

    systemd.services.respeaker-led-bridge = lib.mkIf cfg.leds.enable {
      description = "ReSpeaker LED ring bridge (wyoming events + HTTP notifications)";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-udev-settle.service" ];
      wants = [ "systemd-udev-settle.service" ];
      serviceConfig = {
        Type = "simple";
        User = "wyoming-satellite";
        Group = "wyoming-satellite";
        RuntimeDirectory = "wyoming-satellite";
        RuntimeDirectoryMode = "0770";
        ExecStart = lib.concatStringsSep " " (
          [
            (lib.getExe pkgs.ours.respeaker-led-bridge)
            "--uri"
            "unix:///run/wyoming-satellite/events.sock"
            "--http-port"
            (toString cfg.leds.notificationPort)
          ]
          ++ lib.optionals (cfg.leds.brightness != null) [
            "--brightness"
            (toString cfg.leds.brightness)
          ]
          ++ lib.optional cfg.leds.debug "--debug"
        );
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
