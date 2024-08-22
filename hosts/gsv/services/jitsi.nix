{ config, inputs, ... }:
let
  inherit (inputs.private-settings) domains;
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
          { urls = "stun:turn.${domains.blog}:443"; }
        ];
        iceTransportPolicy = "relay";
      };
      desktopSharingFrameRate = { min = 5; max = 15; };
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
    config.videobridge.ice.harvest.STUN_MAPPING_HARVESTER_ADDRESSES = "turn.${domains.blog}:443";
  };

  sops.secrets.coturn = { owner = "turnserver"; };
  services.coturn = {
    enable = true;
    realm = "turn.${domains.blog}";

    cert = "${config.security.acme.certs."turn.${domains.blog}".directory}/fullchain.pem";
    pkey = "${config.security.acme.certs."turn.${domains.blog}".directory}/key.pem";

    secure-stun = true;
    lt-cred-mech = true;
    use-auth-secret = true;
    static-auth-secret-file = config.sops.secrets.coturn.path;

    no-dtls = true;
    no-tls = true;
    extraConfig = ''
      no-multicast-peers
      total-quota=50
    '';
  };

  services.nginx.virtualHosts = {
    "turn.${domains.blog}" = {
      forceSSL = true;
      enableACME = true;
    };
  };

  services.prosody = {
    extraModules = [ "turn_external" ];
    extraConfig = ''
      turn_external_host = "turn.${domains.blog}"
      turncredentials_secret = "1b217b550603140a7fc27e567cbd68c873a5d450dfd4039444cf261c98aacd0c3c7644598eabd678d784740ec9218076d4ccadeb93defc5c2b1a62bbe58b82d3"
    '';
  };
}
