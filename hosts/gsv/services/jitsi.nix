{
  config,
  lib,
  pkgs,
  private-settings,
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
      hosts.domain = "jitsi.${domains.blog}";
      enableInsecureRoomNameWarning = true;
      audioQuality = {
        stereo = true;
        opusMaxAverageBitrate = 510000;
      };
      p2p = {
        stunServers =
          let
            coturn = config.services.coturn;
            domain = "turn.${domains.blog}";
            port = builtins.toString coturn.listening-port;
            portTls = builtins.toString coturn.tls-listening-port;
          in
          [
            { urls = "stun:${domain}:${port}"; }
            { urls = "stuns:${domain}:${portTls}"; }
            { urls = "turn:${domain}:${port}"; }
            { urls = "turns:${domain}:${portTls}"; }
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
      disableThirdPartyRequests = true;
    };

    interfaceConfig = {
      APP_NAME = "Jitsi Meet @ ${domains.blog}";
      JITSI_WATERMARK_LINK = "https://jitsi.${domains.blog}";
      SHOW_JITSI_WATERMARK = false;
      MOBILE_DOWNLOAD_LINK_ANDROID = "https://f-droid.org/en/packages/org.jitsi.meet/";
    };
  };

  services.jitsi-videobridge = {
    enable = true;
    openFirewall = true;
    nat.harvesterAddresses = lib.mkForce [
      "turns:turn.${domains.blog}:${builtins.toString config.services.coturn.tls-listening-port}"
      "turn:turn.${domains.blog}:${builtins.toString config.services.coturn.listening-port}"
    ];
  };

  services.prosody = {
    extraModules = [ "turn_external" ];
    extraConfig = ''
      turn_external_host = "turn.${domains.blog}"
      turn_external_port = ${builtins.toString config.services.coturn.listening-port}
      turn_external_secret = "${gsv.turnSecret}"
    '';
  };

  # allow prosody to read certificate files
  users.users.prosody.extraGroups = [ "jitsi-meet" ];

  # After a while, jicofo dies and the dreaded "an error occurred!"
  # is seen when the second user joins. This "fixes" that...
  # https://github.com/jitsi/jitsi-meet/issues/1390
  systemd.services.jicofo.serviceConfig.LimitNOFILE = 52428800;
  systemd.services."restart-jicofo" = {
    description = "Restart jicofo service";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe' pkgs.systemd "systemctl"} restart jicofo.service";
    };
  };
  systemd.timers."restart-jicofo" = {
    description = "Timer to restart jicofo every day";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      RandomizedDelaySec = "3h";
    };
  };
}
