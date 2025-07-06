{
  pkgs,
  config,
  ...
}:
{
  vm = {
    id = 2214;
    name = "SRV-ACTUALBUDGET";

    hardware.cores = 2;
    hardware.memory = 4096;
    hardware.storage = "16G";

    certsFor = [
      {
        name = "actual";
        port = config.services.actual.settings.port;
      }
    ];
  };

  services.actual = {
    enable = true;
    settings.hostname = "127.0.0.1";
  };

  nas.backup.enable = true;

  environment.systemPackages =
    let
      restore-actual = pkgs.writeShellApplication {
        name = "restore-actual";
        runtimeInputs = [ pkgs.rsync ];
        text = ''
          ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown actual:actual ${config.nas.backup.location}/actual/ ${config.services.actual.settings.dataDir}
        '';
      };
    in
    [
      restore-actual
      pkgs.rsync
    ];
  systemd = {
    timers."actual-backup-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "actual-backup-daily.service";
      };
    };
    services."actual-backup-daily" = {
      script = ''
        [ "$(stat -f -c %T ${config.nas.backup.location})" == "smb2" ] && ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.actual.settings.dataDir}/ ${config.nas.backup.location}/actual
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  system.stateVersion = "23.11";
}
