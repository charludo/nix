{
  config,
  pkgs,
  private-settings,
  secrets,
  ...
}:
let
  backupDirDaily = "${config.nas.backup.stateLocation}/paperless/daily/";
  backupDirMonthly = "${config.nas.backup.stateLocation}/paperless/monthly/";

  restore-paperless = pkgs.writeShellApplication {
    name = "restore-paperless";
    text = ''
      sudo -u paperless /run/current-system/sw/bin/paperless-manage document_importer "${backupDirDaily}"
    '';
  };
in
{
  vm = {
    id = 2203;
    name = "SRV-PAPERLESS";

    hardware.cores = 4;
    hardware.memory = 4096;
    hardware.storage = "32G";

    networking.openPorts.tcp = [ 8000 ];
    networking.openPorts.udp = [ 8000 ];
  };

  nas.enable = true;
  nas.backup.enable = true;
  nas.extraUsers = [ config.services.paperless.user ];

  services.paperless = {
    enable = true;
    address = "0.0.0.0";
    port = 8000;
    dataDir = "/var/lib/paperless";
    consumptionDir = "${config.nas.location}/Scanner/";
    consumptionDirIsPublic = true;
    openMPThreadingWorkaround = true;
    settings = {
      PAPERLESS_URL = private-settings.domains.paperless;
      PAPERLESS_CONSUMER_IGNORE_PATTERN = [
        ".DS_STORE/*"
        "desktop.ini"
      ];
      PAPERLESS_DBHOST = "/run/postgresql";
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      PAPERLESS_OCR_USER_ARGS = {
        optimize = 1;
        pdfa_image_compression = "lossless";
      };
      PAPERLESS_ENABLE_ALLAUTH = true;
      PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
    };
    environmentFile = config.age.secrets.paperless-openid.path;
  };
  age.secrets.paperless-openid.rekeyFile = secrets.paperless-openid;

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "paperless" ];
    ensureUsers = [
      {
        name = "paperless";
        ensureDBOwnership = true;
      }
    ];
    authentication = ''
      #type database  DBuser  auth-method
      local all       all     trust
    '';
  };

  environment.systemPackages = [ restore-paperless ];

  systemd = {
    timers."paperless-backup-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "paperless-backup-daily.service";
      };
    };
    timers."paperless-backup-monthly" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "monthly";
        Persistent = true;
        Unit = "paperless-backup-monthly.service";
      };
    };

    services."paperless-backup-daily" = {
      script = ''
        /run/current-system/sw/bin/paperless-manage document_exporter "${backupDirDaily}" -p -d
        /run/current-system/sw/bin/paperless-manage document_create_classifier
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
    services."paperless-backup-monthly" = {
      script = ''
        /run/current-system/sw/bin/paperless-manage document_exporter "${backupDirMonthly}" -z
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  system.stateVersion = "23.11";
}
