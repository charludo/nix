{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkPackageOption
    mkOption
    types
    mkIf
    getExe
    mapAttrs
    boolToString
    optionalAttrs
    concatStringsSep
    removeSuffix
    ;

  cfg = config.services.trek;

  stateDir = "/var/lib/trek";

  # The app tree is bind-mounted here from the store.
  appDir = "${stateDir}/app";
in
{
  options.services.trek = {
    enable = mkEnableOption "TREK, a self-hosted collaborative travel planner";

    package = mkPackageOption pkgs "trek" { };

    port = mkOption {
      type = types.port;
      default = 3000;
      description = "Port on which the TREK web interface and API are served";
    };

    address = mkOption {
      type = types.str;
      default = "0.0.0.0";
      example = "127.0.0.1";
      description = ''
        Address TREK binds to.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open {option}`port` in the firewall";
    };

    appUrl = mkOption {
      type = types.str;
      example = "https://trek.example.com";
      description = ''
        Public base URL of this instance, scheme included.
      '';
    };

    allowedOrigins = mkOption {
      type = types.listOf types.str;
      default = [ (removeSuffix "/" cfg.appUrl) ];
      defaultText = lib.literalExpression ''[ (lib.removeSuffix "/" config.services.trek.appUrl) ]'';
      example = [ "https://trek.example.com" ];
      description = ''
        Origins accepted by CORS and the allowlist the WebSocket gateway checks the `Origin` header against.
      '';
    };

    proxy = {
      trustedHops = mkOption {
        type = types.ints.unsigned;
        default = 1;
        description = ''
          Number of reverse proxies in front of TREK, used to pick the client address out of `X-Forwarded-For` 
          and the scheme out of `X-Forwarded-Proto`.
        '';
      };

      forceHttps = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Redirect plain-HTTP requests to HTTPS and add `upgrade-insecure-requests` to the CSP.
        '';
      };

      hstsIncludeSubdomains = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Add `includeSubDomains` to the HSTS header.
        '';
      };
    };

    settings = {
      timeZone = mkOption {
        type = types.nullOr types.str;
        default = config.time.timeZone;
        defaultText = lib.literalExpression "config.time.timeZone";
        example = "Europe/Berlin";
        description = "Timezone used for logs, trip reminders and scheduled tasks";
      };

      logLevel = mkOption {
        type = types.enum [
          "error"
          "warn"
          "info"
          "debug"
        ];
        default = "info";
        description = "Log level";
      };

      defaultLanguage = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "de";
        description = ''
          Language of the login page for users with no saved preference.
          The browser/OS language is auto-detected first, this is only the fallback.
        '';
      };

      sessionDuration = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "7d";
        description = "How long users stay logged in. `null` uses TREK's own default of 24h";
      };

      sessionDurationRemember = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "90d";
        description = ''
          Session length when "Remember me" is ticked at login. `null` uses TREK's own default of 30d.
        '';
      };

      allowInternalNetwork = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Allow TREK to make outbound requests to RFC-1918 addresses.
          Needed to link a self-hosted Immich or Synology Photos library on the same LAN.
        '';
      };
    };

    oidc = {
      issuer = mkOption {
        type = types.str;
        default = "";
        example = "https://sso.example.com";
        description = ''
          OpenID Connect provider URL.
        '';
      };

      clientId = mkOption {
        type = types.str;
        default = "";
        example = "trek";
        description = ''
          OIDC client ID.
        '';
      };

      displayName = mkOption {
        type = types.str;
        default = "";
        description = "Label shown on the SSO login button";
      };

      discoveryUrl = mkOption {
        type = types.str;
        default = "";
        example = "https://sso.example.com/.well-known/openid-configuration";
        description = ''
          Override the discovery endpoint, for providers that do not serve it at the standard path below {option}`oidc.issuer`.
        '';
      };

      scope = mkOption {
        type = types.str;
        default = "";
        example = "openid email profile groups";
        description = ''
          Fully replaces TREK's default of `openid email profile`.
        '';
      };

      only = mkOption {
        type = types.bool;
        default = false;
        description = ''
          SSO-only mode disables password login and registration and overrides the Admin > Settings toggles.
        '';
      };

      adminClaim = mkOption {
        type = types.str;
        default = "";
        example = "groups";
        description = "Claim carrying admin membership. TREK uses `groups` when this is empty";
      };

      adminValue = mkOption {
        type = types.str;
        default = "";
        example = "trek-admins";
        description = "Value of {option}`oidc.adminClaim` that grants the admin role";
      };
    };

    kitinerary = mkOption {
      type = types.nullOr types.package;
      default = pkgs.kdePackages.kitinerary;
      defaultText = lib.literalExpression "pkgs.kdePackages.kitinerary";
      description = ''
        KItinerary provides the extractor that parses booking confirmations (EML, PDF, PKPass, HTML, TXT) into reservations.
        Set to `null` to drop it from the closure. TREK then disables the booking-import feature and says so on startup.
      '';
    };

    extraConfig = mkOption {
      type =
        with types;
        attrsOf (
          nullOr (oneOf [
            bool
            int
            str
          ])
        );
      default = { };
      example = {
        OIDC_ISSUER = "https://auth.example.com";
        OIDC_CLIENT_ID = "trek";
        SMTP_HOST = "mail.example.com";
      };
      description = ''
        TREK is configured through environment variables.
        See [Environment Variables](https://github.com/liketrek/TREK/wiki/Environment-Variables).

        Values here take precedence over the options above.
      '';
    };

    secretsFile = mkOption {
      type = types.nullOr types.path;
      example = "/run/secrets/trek-env";
      description = ''
        Environment file holding the values that must not land in the
        world-readable Nix store — {env}`ENCRYPTION_KEY` above all, plus
        {env}`SMTP_PASS`, {env}`OIDC_CLIENT_SECRET`, {env}`ADMIN_PASSWORD` and
        {env}`UNSPLASH_ACCESS_KEY` if you use them.

        ```
        ENCRYPTION_KEY=...64 hex characters, `openssl rand -hex 32`...
        ```
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services.trek = {
      description = "TREK travel planner";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        NODE_ENV = "production";
        PORT = toString cfg.port;
        HOST = cfg.address;
        LOG_LEVEL = cfg.settings.logLevel;
        APP_URL = cfg.appUrl;

        TRUST_PROXY = toString cfg.proxy.trustedHops;
        FORCE_HTTPS = boolToString cfg.proxy.forceHttps;
        HSTS_INCLUDE_SUBDOMAINS = boolToString cfg.proxy.hstsIncludeSubdomains;
        ALLOW_INTERNAL_NETWORK = boolToString cfg.settings.allowInternalNetwork;
      }
      // lib.filterAttrs (_: v: v != "") {
        OIDC_ISSUER = cfg.oidc.issuer;
        OIDC_CLIENT_ID = cfg.oidc.clientId;
        OIDC_DISPLAY_NAME = cfg.oidc.displayName;
        OIDC_DISCOVERY_URL = cfg.oidc.discoveryUrl;
        OIDC_SCOPE = cfg.oidc.scope;
        OIDC_ADMIN_CLAIM = cfg.oidc.adminClaim;
        OIDC_ADMIN_VALUE = cfg.oidc.adminValue;
      }
      // optionalAttrs (cfg.oidc.issuer != "") { OIDC_ONLY = boolToString cfg.oidc.only; }
      // optionalAttrs (cfg.allowedOrigins != [ ]) {
        ALLOWED_ORIGINS = concatStringsSep "," cfg.allowedOrigins;
      }
      // optionalAttrs (cfg.settings.timeZone != null) { TZ = cfg.settings.timeZone; }
      // optionalAttrs (cfg.settings.defaultLanguage != null) {
        DEFAULT_LANGUAGE = cfg.settings.defaultLanguage;
      }
      // optionalAttrs (cfg.settings.sessionDuration != null) {
        SESSION_DURATION = cfg.settings.sessionDuration;
      }
      // optionalAttrs (cfg.settings.sessionDurationRemember != null) {
        SESSION_DURATION_REMEMBER = cfg.settings.sessionDurationRemember;
      }
      // optionalAttrs (cfg.kitinerary != null) {
        KITINERARY_EXTRACTOR_PATH = "${cfg.kitinerary}/libexec/kf6/kitinerary-extractor";
      }
      // (mapAttrs (_: toString) cfg.extraConfig);

      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        User = "trek";
        Group = "trek";

        StateDirectory = [
          "trek"
          "trek/app"
          "trek/data"
          "trek/uploads"
        ];
        StateDirectoryMode = "0700";

        BindReadOnlyPaths = [ "${cfg.package}/share/trek:${appDir}" ];

        WorkingDirectory = "${appDir}/server";
        ExecStart = getExe cfg.package;

        EnvironmentFile = lib.optional (cfg.secretsFile != null) cfg.secretsFile;

        Restart = "on-failure";
        RestartSec = 5;

        AmbientCapabilities = "";
        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = false; # V8 JITs
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
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
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
      };
    };

    networking.firewall.allowedTCPPorts = lib.optional cfg.openFirewall cfg.port;
  };
}
