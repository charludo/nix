{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.wyomingSatellite;

  eventSocket = "/run/wyoming-satellite/events.sock";

  tuningJson = pkgs.writeText "respeaker-tuning.json" (builtins.toJSON cfg.tuning);
in
{
  options.wyomingSatellite = {
    enable = lib.mkEnableOption "Wyoming satellite for Home Assistant";

    alsaDevice = mkOption {
      type = types.str;
      default = "plughw:CARD=ArrayUAC10,DEV=0";
      description = "ALSA device used for capture and playback";
    };

    name = mkOption {
      type = types.str;
      default = "${config.networking.hostName}-satellite";
      description = "Satellite name advertised to Home Assistant";
    };

    wakeWord = mkOption {
      type = types.str;
      default = "computer";
      description = "Wake word model name handled by wyoming-openwakeword";
    };

    leds = {
      enable = mkEnableOption "ReSpeaker LED ring driven by wyoming events";

      brightness = mkOption {
        type = types.nullOr (types.ints.between 0 31);
        default = null;
        description = "LED ring brightness 0..31 or null for device default";
      };

      notificationPort = mkOption {
        type = types.port;
        default = 10750;
        description = "TCP port for the HTTP notification API";
      };

      openNotificationFirewall = mkOption {
        type = types.bool;
        default = true;
        description = "Open the notification port in the firewall";
      };

      debug = mkOption {
        type = types.bool;
        default = false;
        description = "Enable debug logging in the LED bridge";
      };
    };

    tuning = mkOption {
      type =
        with types;
        attrsOf (oneOf [
          int
          float
        ]);
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

  config = mkIf cfg.enable {
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
      threshold = 0.6;
      customModelsDirectories = [ ../home-assistant/config/assets/wakewords ];
    };

    services.wyoming.satellite = {
      enable = true;
      user = "wyoming-satellite";
      group = "wyoming-satellite";
      name = cfg.name;
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
        "--mic-volume-multiplier"
        "3.0"
      ]
      ++ optionals cfg.leds.enable [
        "--event-uri"
        "unix://${eventSocket}"
      ];
    };

    systemd.services.wyoming-satellite = {
      serviceConfig = {
        PrivateDevices = lib.mkForce false;
        DeviceAllow = lib.mkForce [ "char-alsa rw" ];
        DevicePolicy = lib.mkForce "closed";
      };
      after = mkIf cfg.leds.enable [ "respeaker-led-bridge.service" ];
      requires = mkIf cfg.leds.enable [ "respeaker-led-bridge.service" ];
    };

    networking.firewall.allowedTCPPorts = [
      10700
    ]
    ++ optionals (cfg.leds.enable && cfg.leds.openNotificationFirewall) [
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

    services.udev.extraRules = mkIf (cfg.leds.enable || cfg.tuning != { }) ''
      SUBSYSTEM=="usb", ATTR{idVendor}=="2886", ATTR{idProduct}=="0018", MODE="0660", GROUP="wyoming-satellite"
    '';

    systemd.services.respeaker-tuning-apply = mkIf (cfg.tuning != { }) {
      description = "Apply ReSpeaker XMOS DSP tuning parameters";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-udev-settle.service" ];
      wants = [ "systemd-udev-settle.service" ];
      bindsTo = [ "dev-bus-usb.device" ];
      serviceConfig = {
        Type = "oneshot";
        User = "wyoming-satellite";
        Group = "wyoming-satellite";
        ExecStart = "${pkgs.ours.respeaker-led-bridge}/bin/respeaker-tuning-apply ${tuningJson}";
        Restart = "on-failure";
        RestartSec = 2;
        StartLimitBurst = 5;
      };
    };

    systemd.services.respeaker-led-bridge = mkIf cfg.leds.enable {
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
        ExecStart = concatStringsSep " " (
          [
            "${pkgs.ours.respeaker-led-bridge}/bin/respeaker-led-bridge"
            "--uri"
            "unix://${eventSocket}"
            "--http-port"
            (toString cfg.leds.notificationPort)
          ]
          ++ optionals (cfg.leds.brightness != null) [
            "--brightness"
            (toString cfg.leds.brightness)
          ]
          ++ optional cfg.leds.debug "--debug"
        );
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
