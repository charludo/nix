{ pkgs, config, ... }:
{
  vm = {
    id = 2102;
    name = "SRV-SUWAYOMI";

    hardware.cores = 4;
    hardware.memory = 8192;
    hardware.storage = "32G";

    networking.nameservers = [ "1.1.1.1" ];
  };

  surfshark = {
    enable = true;
    alwaysOn = true;
    hopWeekly = true;
    iptables = {
      enable = true;
      enforceForUsers = [ config.services.suwayomi-server.user ];
    };
  };

  networking.interfaces.ens18.ipv4.routes = [
    {
      address = "192.168.0.0";
      prefixLength = 16;
      via = config.vm.networking.gateway;
    }
  ];

  services.suwayomi-server = {
    enable = true;
    openFirewall = true;

    dataDir = "/var/lib/suwayomi-server";

    settings.server.extensionRepos = [
      "https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json"
      "https://raw.githubusercontent.com/ThePBone/tachiyomi-extensions-revived/repo/index.min.json"
    ];
  };
  users.groups.${config.services.suwayomi-server.user}.gid = 995;

  services.flaresolverr.enable = false; # https://github.com/NixOS/nixpkgs/issues/332776

  services.readarr = {
    enable = true;
    openFirewall = true;
  };

  systemd = {
    services.suwayomi-server.after = [ "media-NAS.mount" ];
    services.readarr.after = [ "media-NAS.mount" ];

    timers."suwayomi-backup-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "suwayomi-backup-daily.service";
      };
    };
    services."suwayomi-backup-daily" = {
      script = ''
        [ "$(stat -f -c %T ${config.nas.backup.location})" == "smb2" ] && ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.suwayomi-server.dataDir}/ ${config.nas.backup.location}/suwayomi
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };

    timers."suwayomi-sync" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
        Unit = "suwayomi-sync.service";
      };
    };
    services."suwayomi-sync" = {
      script = ''
        [ "$(stat -f -c %T ${config.nas.location})" == "smb2" ] && find ${config.services.suwayomi-server.dataDir}/.local/share/Tachidesk/downloads/mangas/*/ -maxdepth 0 -type d -exec ${pkgs.rsync}/bin/rsync -avz --stats --inplace {}/ ${config.nas.location}/Manga \;
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };

    timers."readarr-backup-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "readarr-backup-daily.service";
      };
    };
    services."readarr-backup-daily" = {
      script = ''
        [ "$(stat -f -c %T ${config.nas.backup.location})" != "smb2" ] && exit 1
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.readarr.dataDir}/ ${config.nas.backup.location}/torrenter/readarr2
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  environment.systemPackages =
    let
      suwayomi-init = pkgs.writeShellApplication {
        name = "suwayomi-init";
        text = ''
          [ "$(stat -f -c %T ${config.nas.backup.location})" != "smb2" ] && exit 1
          ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.nas.backup.location}/suwayomi/ ${config.services.suwayomi-server.dataDir}
        '';
      };
      readarr-init = pkgs.writeShellApplication {
        name = "readarr-init";
        text = ''
          [ "$(stat -f -c %T ${config.nas.backup.location})" == "smb2" ] && ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.nas.backup.location}/torrenter/readarr2/ ${config.services.readarr.dataDir}
        '';
      };
    in
    [
      suwayomi-init
      readarr-init
    ];

  nas.enable = true;
  nas.backup.enable = true;
  nas.extraUsers = [
    config.services.suwayomi-server.user
    config.services.readarr.user
  ];

  system.stateVersion = "23.11";
}
