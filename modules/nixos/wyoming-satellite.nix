{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.wyomingSatellite;
in
{
  options.wyomingSatellite = {
    enable = lib.mkEnableOption "Wyoming satellite for Home Assistant (ReSpeaker Mic Array v2.0)";

    alsaDevice = mkOption {
      type = types.str;
      default = "plughw:CARD=ArrayUAC10,DEV=0";
      description = ''
        ALSA device used for capture and playback.
        The ReSpeaker Mic Array v2.0 typically registers as card "ArrayUAC10".
      '';
    };

    name = mkOption {
      type = types.str;
      default = "${config.networking.hostName}-satellite";
      description = "Satellite name advertised to Home Assistant.";
    };

    wakeWord = mkOption {
      type = types.str;
      default = "computer";
      description = "Wake word model name handled by wyoming-openwakeword.";
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
      # ReSpeaker v2.0 outputs audio quietly; lower threshold to compensate.
      threshold = 0.4;
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

      # ReSpeaker outputs audio at a low level; crank gain.
      microphone.autoGain = 20;

      # VAD is pointless when using local wake-word detection.
      vad.enable = false;

      extraArgs = [
        "--wake-uri"
        "tcp://127.0.0.1:10400"
        "--wake-word-name"
        cfg.wakeWord
        "--mic-volume-multiplier"
        "4.0"
      ];
    };

    # Upstream module hides /dev/snd via PrivateDevices=true and an empty
    # DeviceAllow, which assumes a PipeWire/Pulse setup. We talk to ALSA
    # directly, so re-expose sound devices to the service.
    systemd.services.wyoming-satellite.serviceConfig = {
      PrivateDevices = lib.mkForce false;
      DeviceAllow = lib.mkForce [ "char-alsa rw" ];
      DevicePolicy = lib.mkForce "closed";
    };

    networking.firewall.allowedTCPPorts = [ 10700 ];

    # The ReSpeaker is dedicated to the satellite; keep PipeWire/WirePlumber
    # from grabbing it so arecord/aplay have exclusive access.
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
  };
}
