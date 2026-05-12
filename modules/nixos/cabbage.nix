{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.cabbage;
  inherit (lib)
    mkEnableOption
    mkPackageOption
    mkOption
    types
    mkIf
    ;

  user = cfg.user;
  group = cfg.group;
  stateDir = cfg.dataDir;
  stateDirName = lib.removePrefix "/var/lib/" stateDir;

  stateSubdirs = [
    "${stateDirName}/storage/app/private"
    "${stateDirName}/storage/app/public"
    "${stateDirName}/storage/framework/cache/data"
    "${stateDirName}/storage/framework/sessions"
    "${stateDirName}/storage/framework/views"
    "${stateDirName}/storage/logs"
    "${stateDirName}/bootstrap/cache"
    "${stateDirName}/database"
  ];

  envAttrs = {
    APP_NAME = cfg.appName;
    APP_ENV = "production";
    APP_DEBUG = "0";
    APP_TIMEZONE = if cfg.timezone == null then config.time.timeZone else cfg.timezone;
    APP_URL = "https://${cfg.hostname}";
    APP_LOCALE = "en";
    APP_FALLBACK_LOCALE = "en";

    LARAVEL_STORAGE_PATH = "${stateDir}/storage";
    APP_SERVICES_CACHE = "${stateDir}/bootstrap/cache/services.php";
    APP_PACKAGES_CACHE = "${stateDir}/bootstrap/cache/packages.php";
    APP_CONFIG_CACHE = "${stateDir}/bootstrap/cache/config.php";
    APP_ROUTES_CACHE = "${stateDir}/bootstrap/cache/routes-v7.php";
    APP_EVENTS_CACHE = "${stateDir}/bootstrap/cache/events.php";

    LOG_CHANNEL = "stack";
    LOG_STACK = "single";
    LOG_LEVEL = "warning";

    DB_CONNECTION = "sqlite";
    DB_DATABASE = "${stateDir}/database/database.sqlite";

    SESSION_DRIVER = "database";
    SESSION_LIFETIME = "120";
    SESSION_ENCRYPT = "0";

    CACHE_STORE = "database";
    QUEUE_CONNECTION = "database";
    BROADCAST_CONNECTION = "log";
    FILESYSTEM_DISK = "local";

    MAIL_MAILER = "log";

    BCRYPT_ROUNDS = "12";
    MAX_ATTENDEES_PER_MEETING = toString cfg.maxAttendeesPerMeeting;

    DONATE_ACTIVE = if cfg.donate.active then "1" else "0";
    DONATE_MONERO_ADDRESS = cfg.donate.moneroAddress;
    DONATE_EMAIL_ADDRESS = cfg.donate.emailAddress;

    ADMIN_NOTIFICATION_EMAIL = cfg.adminNotificationEmail;
    BACKUP_ARCHIVE_PASSWORD = "nul";
  }
  // cfg.extraConfig;

  envFiltered = lib.filterAttrs (_: v: v != null && toString v != "") envAttrs;

  phpCli = "${cfg.package.passthru.php}/bin/php";
in
{
  options.services.cabbage = {
    enable = mkEnableOption "cabbage.gay, an encrypted scheduling poll service";

    package = mkPackageOption pkgs "cabbage" { };

    user = mkOption {
      type = types.str;
      default = "cabbage";
      description = "User the cabbage services run as.";
    };

    group = mkOption {
      type = types.str;
      default = "cabbage";
      description = "Group the cabbage services run as.";
    };

    hostname = mkOption {
      type = types.str;
      example = "cabbage.example.org";
      description = ''
        Domain under which cabbage.gay is served.
      '';
    };

    appName = mkOption {
      type = types.str;
      default = "cabbage.gay";
      description = "Display name (`APP_NAME`).";
    };

    timezone = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Application timezone (`APP_TIMEZONE`). Defaults to `config.time.timeZone`.";
    };

    environmentFile = mkOption {
      type = types.path;
      example = "/run/secrets/cabbage.env";
      description = ''
        Path to a file passed to the service units as `EnvironmentFile=`. It
        must define at least `APP_KEY` (Laravel's app key, generated with
        `echo "base64:$(openssl rand -base64 32)"`), one line per variable in
        standard `KEY=VALUE` form.
      '';
    };

    adminNotificationEmail = mkOption {
      type = types.str;
      default = "";
      description = "Email address that receives admin notifications. Empty disables them.";
    };

    maxAttendeesPerMeeting = mkOption {
      type = types.int;
      default = 512;
      description = "Upper bound on meeting size.";
    };

    donate = {
      active = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Show donation prompts in the UI. Setting this to `false` is
          currently broken upstream: cabbage's Blade templates call
          `route('donate')` unconditionally, but the route itself is only
          registered when this is true.
        '';
      };
      moneroAddress = mkOption {
        type = types.str;
        default = "";
        description = "Monero address for donations.";
      };
      emailAddress = mkOption {
        type = types.str;
        default = "";
        description = "Contact address for donation enquiries.";
      };
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/cabbage";
      description = "Directory holding the runtime state (storage, cache, sqlite DB).";
    };

    nginx = mkOption {
      type = types.nullOr (
        types.submodule (
          import (pkgs.path + "/nixos/modules/services/web-servers/nginx/vhost-options.nix") {
            inherit config lib;
          }
        )
      );
      default = { };
      example = {
        forceSSL = true;
        enableACME = true;
      };
      description = "Per-vhost overrides; set to `null` to disable the nginx vhost.";
    };

    poolConfig = mkOption {
      type = types.attrsOf (
        types.oneOf [
          types.str
          types.int
          types.bool
        ]
      );
      default = {
        "pm" = "dynamic";
        "pm.max_children" = 32;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 2;
        "pm.max_spare_servers" = 4;
        "pm.max_requests" = 500;
      };
      description = "Settings for the php-fpm pool serving cabbage.";
    };

    extraConfig = mkOption {
      type = types.attrsOf (
        types.nullOr (
          types.oneOf [
            types.str
            types.int
            types.bool
          ]
        )
      );
      default = { };
      description = "Additional environment variables to pass to cabbage.";
    };
  };

  config = mkIf cfg.enable {
    users.users = mkIf (user == "cabbage") {
      cabbage = {
        isSystemUser = true;
        inherit group;
        home = stateDir;
      };
    };
    users.groups = mkIf (group == "cabbage") { cabbage = { }; };

    assertions = [
      {
        assertion = lib.hasPrefix "/var/lib/" stateDir;
        message = "services.cabbage.dataDir must live under /var/lib/ so systemd's StateDirectory can manage it.";
      }
    ];

    systemd.services.cabbage-migrate = {
      description = "Run cabbage.gay database migrations and warm caches";
      wantedBy = [ "multi-user.target" ];
      before = [
        "phpfpm-cabbage.service"
        "cabbage-queue.service"
      ];
      restartTriggers = [
        cfg.package
        (builtins.toJSON envFiltered)
      ];
      environment = envFiltered;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = user;
        Group = group;
        WorkingDirectory = cfg.package;
        EnvironmentFile = cfg.environmentFile;
        StateDirectory = stateSubdirs;
        StateDirectoryMode = "0750";
      };
      script = ''
        set -euo pipefail
        [ -e ${stateDir}/database/database.sqlite ] \
          || ${pkgs.coreutils}/bin/touch ${stateDir}/database/database.sqlite
        ${phpCli} ${cfg.package}/artisan package:discover --ansi
        ${phpCli} ${cfg.package}/artisan migrate --force --no-interaction
        ${phpCli} ${cfg.package}/artisan config:cache
        ${phpCli} ${cfg.package}/artisan view:cache
      '';
    };

    services.phpfpm.pools.cabbage = {
      inherit user group;
      phpPackage = cfg.package.passthru.php;
      phpOptions = ''
        log_errors = on
      '';
      phpEnv = envFiltered;
      settings = {
        "listen.mode" = "0660";
        "listen.owner" = config.services.nginx.user;
        "listen.group" = config.services.nginx.group;
        "catch_workers_output" = true;
        "clear_env" = "no";
      }
      // cfg.poolConfig;
    };

    systemd.services.phpfpm-cabbage = {
      after = [ "cabbage-migrate.service" ];
      requires = [ "cabbage-migrate.service" ];
      serviceConfig.EnvironmentFile = cfg.environmentFile;
      serviceConfig.StateDirectory = stateSubdirs;
      serviceConfig.StateDirectoryMode = "0750";
    };

    systemd.services.cabbage-queue = {
      description = "cabbage.gay Laravel queue worker";
      wantedBy = [ "multi-user.target" ];
      after = [ "cabbage-migrate.service" ];
      requires = [ "cabbage-migrate.service" ];
      environment = envFiltered;
      serviceConfig = {
        User = user;
        Group = group;
        WorkingDirectory = cfg.package;
        EnvironmentFile = cfg.environmentFile;
        StateDirectory = stateSubdirs;
        StateDirectoryMode = "0750";
        ExecStart = "${phpCli} ${cfg.package}/artisan queue:work --queue=default --sleep=3 --tries=3 --max-time=3600";
        Restart = "always";
        RestartSec = 30;
      };
    };

    services.nginx = mkIf (cfg.nginx != null) {
      enable = true;
      virtualHosts."${cfg.hostname}" = lib.mkMerge [
        cfg.nginx
        {
          root = lib.mkForce "${cfg.package}/public";
          extraConfig = ''
            index index.php;
          '';
          locations = {
            "/" = {
              tryFiles = "$uri $uri/ /index.php?$query_string";
            };
            "~ \\.php$" = {
              priority = 500;
              extraConfig = ''
                fastcgi_pass unix:${config.services.phpfpm.pools.cabbage.socket};
                fastcgi_split_path_info ^(.+\.php)(/.*)$;
                include ${config.services.nginx.package}/conf/fastcgi_params;
                fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
                fastcgi_param DOCUMENT_ROOT $realpath_root;
                fastcgi_param PATH_INFO $fastcgi_path_info;
              '';
            };
            "= /favicon.ico" = {
              extraConfig = "access_log off; log_not_found off;";
            };
            "= /robots.txt" = {
              extraConfig = "access_log off; log_not_found off;";
            };
          };
        }
      ];
    };
  };
}
