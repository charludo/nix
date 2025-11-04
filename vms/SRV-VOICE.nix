{ config, lib, ... }:
let
  wyoming = config.services.wyoming;
  toPort = uri: lib.toInt (lib.last (lib.splitString ":" uri));
in
{
  vm = {
    id = 2402;
    name = "SRV-VOICE";
    runOnGPUHost = true;

    hardware.cores = 6;
    hardware.memory = 32768;
    hardware.storage = "32G";

    networking.openPorts.tcp = [
      (toPort wyoming.openwakeword.uri)
      (toPort wyoming.piper.servers.default.uri)
      (toPort wyoming.faster-whisper.servers.de.uri)
    ];
  };

  services.wyoming = {
    openwakeword.enable = true;

    piper.servers.default = {
      enable = true;
      voice = "de_DE-thorsten-high";
      uri = "tcp://0.0.0.0:10200";
    };

    faster-whisper.servers.de = {
      enable = true;
      model = "base";
      beamSize = 0;
      language = "de";
      uri = "tcp://0.0.0.0:10300";
      initialPrompt = ''
        Das Folgende ist ein Befehl an einen Sprachassistenten.
        Geräte wie "Licht", Zimmer wie "Wohnzimmer" oder "Schlafzimmer", oder Uhrzeiten können vorkommen.
      '';
    };
  };
  systemd.services."wyoming-faster-whisper-de".serviceConfig.ProcSubset = lib.mkForce "all";

  system.stateVersion = "23.11";
}
