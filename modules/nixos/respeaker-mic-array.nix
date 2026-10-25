{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.respeaker-mic-array;
  lva = config.services.linux-voice-assistant;
in
{
  options.hardware.respeaker-mic-array = {
    enable = lib.mkEnableOption ''
      support for the ReSpeaker Mic Array v2.0 (XMOS XVF-3000, USB 2886:0018).
      The firmware variant is flashed imperatively with `respeaker-dfu`; the
      1-channel firmware delivers only the processed ASR channel
    '';

    package = lib.mkPackageOption pkgs.ours "respeaker-led-bridge" { };

    leds = lib.mkEnableOption ''
      the LED ring, driven by Linux-Voice-Assistant's state (wake word,
      listening, thinking, speaking, timers, mute). Also offers the ring to
      Home Assistant as a light
    '';

    tuning = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.oneOf [
          lib.types.int
          lib.types.float
        ]
      );
      default = { };
      example = {
        AGCONOFF = 0;
        HPFONOFF = 1;
      };
      description = ''
        XVF-3000 DSP parameters applied whenever the array appears (boot and
        replug). Empty leaves the chip's defaults. The chip forgets applied
        values on power loss, so replug it after emptying this to get the
        defaults back.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.leds -> (lva.enable && lva.peripheralApi);
        message = "hardware.respeaker-mic-array.leds needs services.linux-voice-assistant with peripheralApi.";
      }
    ];

    users.groups.respeaker = { };

    # USB control access (LEDs, tuning) without root.
    services.udev.extraRules = ''
      SUBSYSTEM=="usb", ATTR{idVendor}=="2886", ATTR{idProduct}=="0018", MODE="0660", GROUP="respeaker"
    ''
    + lib.optionalString (cfg.tuning != { }) ''
      ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="2886", ATTR{idProduct}=="0018", TAG+="systemd", ENV{SYSTEMD_WANTS}+="respeaker-tuning.service"
    '';

    systemd.services.respeaker-leds = lib.mkIf cfg.leds {
      description = "ReSpeaker LED ring following Linux-Voice-Assistant";
      wantedBy = [ "multi-user.target" ];
      # No BindsTo: LVA exits and restarts once at boot when the network
      # isn't up yet, which would stop this unit for good. The controller
      # reconnects to LVA's API by itself.
      after = [ "linux-voice-assistant.service" ];
      serviceConfig = {
        ExecStart = lib.getExe cfg.package;
        DynamicUser = true;
        SupplementaryGroups = [ "respeaker" ];
        Restart = "always";
        RestartSec = 5;
      };
    };

    systemd.services.respeaker-tuning = lib.mkIf (cfg.tuning != { }) {
      description = "Apply ReSpeaker XMOS DSP tuning parameters";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe' cfg.package "respeaker-tuning-apply"} ${pkgs.writeText "respeaker-tuning.json" (builtins.toJSON cfg.tuning)}";
        DynamicUser = true;
        SupplementaryGroups = [ "respeaker" ];
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
