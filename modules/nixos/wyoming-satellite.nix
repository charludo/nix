{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.wyomingSatellite;
in
{
  options.wyomingSatellite = {
    enable = lib.mkEnableOption "Wyoming satellite for Home Assistant";

    alsaDevice = lib.mkOption {
      type = lib.types.str;
      default = "plughw:CARD=ArrayUAC10,DEV=0";
      description = "ALSA device used for capture and playback";
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
      name = cfg.name;
      area = lib.mkIf (cfg.area != null) cfg.area;
      uri = "tcp://0.0.0.0:10700";

      microphone.command = "${pkgs.alsa-utils}/bin/arecord -D ${cfg.alsaDevice} -r 16000 -c 1 -f S16_LE -t raw";
      sound.command = "${pkgs.alsa-utils}/bin/aplay -D ${cfg.alsaDevice} -r 22050 -c 1 -f S16_LE -t raw";
      microphone.autoGain = 0;
      vad.enable = false;

      extraArgs = [
        "--wake-uri"
        "tcp://127.0.0.1:10400"
        "--wake-word-name"
        cfg.wakeWord
      ]
      ++ lib.optionals cfg.leds.enable [
        "--event-uri"
        "unix:///run/wyoming-satellite/events.sock"
      ];
    };

    systemd.services.wyoming-satellite = {
      serviceConfig = {
        PrivateDevices = lib.mkForce false;
        DeviceAllow = lib.mkForce [ "char-alsa rw" ];
        DevicePolicy = lib.mkForce "closed";
        Restart = lib.mkForce "on-failure";
        RestartSec = 5;
        StartLimitBurst = 30;
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
