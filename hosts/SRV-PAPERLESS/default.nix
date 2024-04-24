{ inputs, pkgs, ... }:
let
  backupDirDaily = "/media/Backup/paperless/daily/";
  backupDirMonthly = "/media/Backup/paperless/monthly/";

  paperless-init = pkgs.writeShellApplication {
    name = "paperless-init";
    text = ''
      sudo -u paperless /var/lib/paperless/paperless-manage document_importer "${backupDirDaily}"
    '';
  };
in
{
  _module.args.defaultUser = "paki";
  imports =
    [
      ./hardware-configuration.nix
      ../common/optional/vmify.nix

      ../common/global
      ../common/optional/nvim.nix

      ../../users/paki/user.nix
    ];

  enableNas = true;
  enableNasBackup = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "SRV-PAPERLESS";
    interfaces = {
      ens18.ipv4.addresses = [{
        address = "192.168.20.37";
        prefixLength = 27;
      }];
    };
    defaultGateway = "192.168.20.34";
    nameservers = [ "192.168.30.5" "192.168.30.13" "1.1.1.1" ];
    firewall = {
      allowedTCPPorts = [ 8000 ];
      allowedUDPPorts = [ 8000 ];
    };
  };

  services.qemuGuest.enable = true;

  users.users.paperless.extraGroups = [ "nas" ];
  services.paperless = {
    enable = true;
    address = "0.0.0.0";
    port = 8000;
    dataDir = "/var/lib/paperless";
    consumptionDir = "/media/NAS/Scanner/";
    consumptionDirIsPublic = true;
    openMPThreadingWorkaround = true;
    settings = {
      PAPERLESS_URL = inputs.private-settings.domains.paperless;
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
    };
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "paperless" ];
    ensureUsers = [{ name = "paperless"; ensureDBOwnership = true; }];
    authentication = ''
      #type database  DBuser  auth-method
      local all       all     trust
    '';
  };

  environment.systemPackages = [ paperless-init ];

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
        /var/lib/paperless/paperless-manage document_exporter "${backupDirDaily}" -p -d
        /var/lib/paperless/paperless-manage document_create_classifier
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
    services."paperless-backup-monthly" = {
      script = ''
        /var/lib/paperless/paperless-manage document_exporter "${backupDirMonthly}" -z
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  system.stateVersion = "23.11";
}
