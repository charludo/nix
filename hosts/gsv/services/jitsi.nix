{
  config,
  private-settings,
  secrets,
  ...
}:
let
  inherit (private-settings) domains gsv;
in
{
  services.jitsi-meet = {
    enable = true;
    hostName = "jitsi.${domains.blog}";
    nginx.enable = true;

    videobridge.enable = true;
    secureDomain = {
      enable = true;
      authentication = "internal_hashed";
    };

    config = {
      hosts.anonymousdomain = "guest.jitsi.${domains.blog}";
      hosts.authdomain = "jitsi.${domains.blog}";
      authdomain = "jitsi.${domains.blog}";
      enableInsecureRoomNameWarning = true;
      audioQuality = {
        stereo = true;
        opusMaxAverageBitrate = 510000;
      };
      p2p = {
        stunServers = [
          { urls = "stun:turn.${domains.blog}:${builtins.toString config.services.coturn.listening-port}"; }
        ];
        iceTransportPolicy = "relay";
      };
      desktopSharingFrameRate = {
        min = 5;
        max = 15;
      };
      constraints.video.height = {
        ideal = 1080;
        max = 1920;
        min = 240;
      };
      maxFullResolutionParticipants = -1;
    };

    interfaceConfig = {
      APP_NAME = "Jitsi Meet @ ${domains.blog}";
      JITSI_WATERMARK_LINK = "https://jitsi.${domains.blog}";
      SHOW_JITSI_WATERMARK = false;
    };
  };

  services.jitsi-videobridge = {
    enable = true;
    openFirewall = true;
    config.videobridge.ice.harvest.STUN_MAPPING_HARVESTER_ADDRESSES =
      "turn.${domains.blog}:${builtins.toString config.services.coturn.listening-port}";
  };

  services.prosody = {
    extraModules = [ "turn_external" ];
    extraConfig = ''
      turn_external_host = "turn.${domains.blog}"
      turn_external_port = ${builtins.toString config.services.coturn.listening-port}
      turn_external_secret = "${gsv.turnSecret}"
    '';
  };

  age.secrets.coturn-env = {
    rekeyFile = secrets.gsv-coturn-env;
    owner = "prosody";
  };
  systemd.services.prosody.serviceConfig.EnvironmentFile = config.age.secrets.coturn-env.path;

  nixpkgs.config.permittedInsecurePackages = [
    "jitsi-meet-1.0.8043"
  ];
}
