{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.linux-voice-assistant;
in
{
  options.services.linux-voice-assistant = {
    enable = lib.mkEnableOption ''
      Linux-Voice-Assistant, a voice satellite that Home Assistant sees as an
      ESPHome device. Wake word detection (microWakeWord) runs locally; HA
      connects to it on port 6053. Wake word, pipeline and sensitivity are
      chosen on the device page in HA and persisted by LVA itself
    '';

    package = lib.mkPackageOption pkgs.ours "linux-voice-assistant" { };

    name = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = "Device name shown in Home Assistant.";
    };

    audioInputDevice = lib.mkOption {
      type = lib.types.str;
      example = "ReSpeaker";
      description = "Microphone, matched as a substring against the PipeWire source names.";
    };

    audioInputChannels = lib.mkOption {
      type = lib.types.enum [
        1
        2
      ];
      default = 1;
      description = "Channels to capture from the microphone.";
    };

    audioOutputDevice = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "alsa/plughw:CARD=Dummy";
      description = "mpv audio device for responses and sounds. `null` uses the default sink.";
    };

    wakeModel = lib.mkOption {
      type = lib.types.str;
      default = "okay_nabu";
      description = ''
        Wake word model used until one is chosen in Home Assistant, which
        then takes precedence. Stick to microWakeWord models on aarch64:
        openWakeWord models crash there (see the package).
      '';
    };

    peripheralApi = lib.mkEnableOption ''
      LVA's peripheral WebSocket API on 127.0.0.1:6055, which LED and button
      controllers use to follow and control the assistant
    '';

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra command line arguments.";
    };
  };

  config = lib.mkIf cfg.enable {
    # LVA reads the mic through the Pulse API. A satellite has no logged-in
    # users, so PipeWire runs system-wide and LVA is a plain system service.
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      pulse.enable = true;
      alsa.enable = true;
      systemWide = true;
    };

    users.users.lva = {
      isSystemUser = true;
      group = "lva";
      extraGroups = [
        "audio" # ALSA devices opened directly, e.g. a dummy output card
        "pipewire" # the system-wide PipeWire sockets
      ];
    };
    users.groups.lva = { };

    systemd.services.linux-voice-assistant = {
      description = "Linux-Voice-Assistant (ESPHome voice satellite)";
      wantedBy = [ "multi-user.target" ];
      wants = [
        "network-online.target"
        "pipewire-pulse.socket"
        "wireplumber.service"
      ];
      after = [
        "network-online.target"
        "pipewire-pulse.socket"
        "wireplumber.service"
      ];
      environment.PULSE_SERVER = "unix:/run/pulse/native";
      serviceConfig = {
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe cfg.package)
            "--name"
            cfg.name
            "--audio-input-device"
            cfg.audioInputDevice
            "--audio-input-channels"
            (toString cfg.audioInputChannels)
            "--wake-model"
            cfg.wakeModel
            "--preferences-file"
            "/var/lib/linux-voice-assistant/preferences.json"
            "--download-dir"
            "/var/lib/linux-voice-assistant/local"
            "--port"
            "6053"
          ]
          ++ lib.optionals (cfg.audioOutputDevice != null) [
            "--audio-output-device"
            cfg.audioOutputDevice
          ]
          ++ (
            if cfg.peripheralApi then
              [
                "--peripheral-host"
                "127.0.0.1"
              ]
            else
              [ "--disable-peripheral-api" ]
          )
          ++ cfg.extraArgs
        );
        User = "lva";
        Group = "lva";
        StateDirectory = "linux-voice-assistant";
        # Also covers starting before the network is up: LVA picks its
        # interface and IP once at startup and exits without one.
        Restart = "always";
        RestartSec = 5;
      };
    };

    networking.firewall.allowedTCPPorts = [ 6053 ]; # ESPHome API, HA connects in
    networking.firewall.allowedUDPPorts = [ 5353 ]; # mDNS, for HA's auto-discovery
  };
}
