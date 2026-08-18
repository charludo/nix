self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dwd-proxy;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption

    optional
    types
    ;
in
{
  options.services.dwd-proxy = {
    enable = mkEnableOption "the DWD radar caching proxy";

    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.dwd-proxy;
      defaultText = lib.literalExpression "dwd-proxy.packages.\${system}.dwd-proxy";
      description = "The dwd-proxy package to use.";
    };

    latitude = mkOption {
      type = types.float;
      example = 52.52;
      description = ''
        Latitude of the centre of the prefetched area, in degrees.
      '';
    };

    longitude = mkOption {
      type = types.float;
      example = 13.405;
      description = ''
        Longitude of the centre of the prefetched area, in degrees.
      '';
    };

    radiusKm = mkOption {
      type = types.ints.positive;
      default = 250;
      description = ''
        Ground radius around the centre to prefetch, in kilometres. Every tile
        request that falls inside this area is served from cache; anything
        outside it is relayed to the upstream service.
      '';
    };

    masterSize = mkOption {
      type = types.ints.positive;
      default = 2048;
      description = ''
        Edge length in pixels of each cached raster. Together with
        {option}`radiusKm` this sets the cache's ground resolution; the source
        product is a 1 km grid, so there is nothing to gain from a resolution
        much finer than that.
      '';
    };

    past = mkOption {
      type = types.str;
      default = "2h";
      description = "How far back to keep frames, as a Go duration.";
    };

    forecast = mkOption {
      type = types.str;
      default = "2h";
      description = ''
        How far ahead to keep forecast frames, as a Go duration. The upstream
        nowcast currently reaches about two hours out; the window is clamped to
        whatever the service actually advertises.
      '';
    };

    interval = mkOption {
      type = types.str;
      default = "1m";
      description = ''
        How often the frame window is reconciled, as a Go duration. Each pass
        fetches the capabilities document, so there is little point polling much
        faster than the five-minute cadence at which new frames appear.
      '';
    };

    forecastMaxAge = mkOption {
      type = types.str;
      default = "5m";
      description = ''
        How long clients may reuse a forecast frame, as a Go duration. Frames
        whose valid time has passed are immutable and always served with a
        one-year lifetime regardless of this setting.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port to listen on.";
    };

    address = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Address to bind to.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open {option}`port` in the firewall.";
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "-decoded-cache=16" ];
      description = "Extra command-line arguments.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.dwd-proxy = {
      description = "DWD radar caching proxy";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe cfg.package)
            "-addr=${cfg.address}:${toString cfg.port}"
            "-state-dir=/var/lib/dwd-proxy"
            "-lat=${toString cfg.latitude}"
            "-lon=${toString cfg.longitude}"
            "-radius-km=${toString cfg.radiusKm}"
            "-master-size=${toString cfg.masterSize}"
            "-past=${cfg.past}"
            "-forecast=${cfg.forecast}"
            "-interval=${cfg.interval}"
            "-forecast-max-age=${cfg.forecastMaxAge}"
          ]
          ++ cfg.extraArgs
        );

        DynamicUser = true;
        StateDirectory = "dwd-proxy";
        StateDirectoryMode = "0700";
        Restart = "always";
        RestartSec = 5;

        # The service only needs to make outbound HTTPS requests and serve HTTP.
        AmbientCapabilities = optional (cfg.port < 1024) "CAP_NET_BIND_SERVICE";
        CapabilityBoundingSet = optional (cfg.port < 1024) "CAP_NET_BIND_SERVICE";
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
          "~@resources"
        ];
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
      };
    };

    networking.firewall.allowedTCPPorts = optional cfg.openFirewall cfg.port;
  };
}
