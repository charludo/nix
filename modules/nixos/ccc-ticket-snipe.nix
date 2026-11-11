{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.ccc-ticket-snipe;
in
{
  options.services.ccc-ticket-snipe = {
    enable = lib.mkEnableOption "a single precisely timed request to the CCC ticket shop at presale start";

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://tickets.events.ccc.de/40c3/";
      description = "Ticket shop URL to request.";
    };

    at = lib.mkOption {
      type = lib.types.str;
      default = "2026-11-08T11:00:00+01:00";
      description = "ISO 8601 time at which the shop opens.";
    };

    minOffsetMs = lib.mkOption {
      type = lib.types.number;
      default = -18;
      description = "The request arrives at a random time between this and `maxOffsetMs` ms relative to `at` (negative: before).";
    };

    maxOffsetMs = lib.mkOption {
      type = lib.types.number;
      default = 22;
      description = "Upper end of the arrival window, see `minOffsetMs`. The jitter spreads attempts across sales in case the shop opens early or late; an early arrival is covered by the second request.";
    };

    secondAtMs = lib.mkOption {
      type = lib.types.numbers.nonnegative;
      default = 40;
      description = "If the first response is still the closed shop page, a second request arrives no earlier than this many ms after `at`.";
    };

    userAgent = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "Mozilla/5.0 (X11; Linux x86_64; rv:159.0) Gecko/20100101 Firefox/159.0";
      description = "User-Agent to send; ideally the one of the browser that takes over the session.";
    };

    package = lib.mkPackageOption pkgs.ours "ccc-ticket-snipe" { };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.ccc-ticket-snipe = {
      description = "CCC ticket shop presale request";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      environment.PYTHONUNBUFFERED = "1";
      serviceConfig = {
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe cfg.package)
            "--url"
            cfg.url
            "--at"
            cfg.at
            "--min-offset-ms"
            (toString cfg.minOffsetMs)
            "--max-offset-ms"
            (toString cfg.maxOffsetMs)
            "--second-at-ms"
            (toString cfg.secondAtMs)
          ]
          ++ lib.optionals (cfg.userAgent != null) [
            "--user-agent"
            cfg.userAgent
          ]
        );
        # Exits 0 after firing (or when the target is long past); a marker in the
        # state directory prevents firing twice for the same target.
        Restart = "on-failure";
        RestartSec = "2s";
        DynamicUser = true;
        StateDirectory = "ccc-ticket-snipe";
        # The full HTML goes to the journal, don't let rate limiting eat it.
        LogRateLimitIntervalSec = 0;
        Nice = -10;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
      unitConfig.StartLimitIntervalSec = 0;
    };
  };
}
