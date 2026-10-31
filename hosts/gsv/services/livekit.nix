{
  config,
  private-settings,
  secrets,
  ...
}:
let
  inherit (private-settings) domains gsv;

  host = "livekit.${domains.blog}";
  jwtPort = 8081;
  rtcTcpPort = 7881;
in
{
  age.secrets.livekit.rekeyFile = secrets.gsv-livekit;

  services.livekit = {
    enable = true;
    keyFile = config.age.secrets.livekit.path;

    settings = {
      port = 7880;
      bind_addresses = [ "127.0.0.1" ];
      rtc = {
        tcp_port = rtcTcpPort;
        port_range_start = 30000;
        port_range_end = 30100;
        use_external_ip = false;
        node_ip = gsv.ip;
        enable_loopback_candidate = false;
      };
      room.auto_create = false;
    };
  };

  services.lk-jwt-service = {
    enable = true;
    livekitUrl = "wss://${host}";
    keyFile = config.age.secrets.livekit.path;
    port = jwtPort;
  };
  systemd.services.lk-jwt-service.environment.LIVEKIT_FULL_ACCESS_HOMESERVERS =
    "matrix.${domains.home}";

  services.nginx.virtualHosts.${host} = {
    forceSSL = true;
    enableACME = true;
    locations = {
      "~ ^/(sfu/get|healthz|get_token)" = {
        proxyPass = "http://127.0.0.1:${toString jwtPort}";
      };
      "/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.livekit.settings.port}";
        proxyWebsockets = true;
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ rtcTcpPort ];
    allowedUDPPortRanges = [
      {
        from = config.services.livekit.settings.rtc.port_range_start;
        to = config.services.livekit.settings.rtc.port_range_end;
      }
    ];
  };
}
