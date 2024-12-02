{ config, lib, ... }:
let
  wyoming = config.services.wyoming;
  toPort = uri: lib.toInt (lib.last (lib.splitString ":" uri));
in
{
  imports = [ ./_common.nix ];

  vm = {
    id = 2402;
    name = "SRV-VOICE";

    hardware.cores = 6;
    hardware.memory = 16384;
    hardware.storage = "12G";

    networking.openPorts.tcp = [
      (toPort wyoming.openwakeword.uri)
      (toPort wyoming.piper.servers.default.uri)
      (toPort wyoming.faster-whisper.servers.de.uri)
    ];
  };

  services.wyoming = {
    openwakeword = {
      enable = true;
      preloadModels = [
        "alexa"
        "hey_jarvis"
        "hey_mycroft"
        "hey_rhasspy"
        "ok_nabu"
      ];
    };

    piper.servers.default = {
      enable = true;
      voice = "de_DE-thorsten-high";
      uri = "tcp://0.0.0.0:10200";
    };

    faster-whisper.servers.de = {
      enable = true;
      model = "Systran/faster-whisper-tiny";
      beamSize = 5;
      language = "de";
      uri = "tcp://0.0.0.0:10300";
    };
  };
  systemd.services."wyoming-faster-whisper-de".serviceConfig.ProcSubset = lib.mkForce "all";

  services.ollama = {
    enable = false;
    openFirewall = true;
    loadModels = [ "llama3.1:8b" "stablelm2:1.6b" "fixt/home-3b-v3:latest" ];
    host = "0.0.0.0";
    acceleration = false;
  };

  system.stateVersion = "23.11";
}
