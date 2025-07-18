{
  pkgs,
  config,
  private-settings,
  ...
}:
{
  vm = {
    id = 2207;
    name = "SRV-AUDIOBOOKSHELF";

    hardware.cores = 4;
    hardware.memory = 16384;
    hardware.storage = "32G";

    networking.nameservers = private-settings.upstreamDNS.ips;
  };

  services.audiobookshelf = {
    enable = true;
    openFirewall = true;
    host = "0.0.0.0";
  };

  nas.enable = true;
  nas.backup.enable = true;
  nas.extraUsers = [ config.services.audiobookshelf.user ];

  systemd = {
    timers."audiobookshelf-backup-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "audiobookshelf-backup-daily.service";
      };
    };
    services."audiobookshelf-backup-daily" = {
      script = ''
        [ "$(stat -f -c %T ${config.nas.backup.stateLocation})" == "smb2" ] && ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.audiobookshelf.dataDir}/ ${config.nas.backup.stateLocation}/audiobookshelf
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  environment.systemPackages =
    let
      restore-audiobookshelf = pkgs.writeShellApplication {
        name = "restore-audiobookshelf";
        runtimeInputs = [ pkgs.rsync ];
        text = ''
          ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.audiobookshelf.user}:${config.services.audiobookshelf.group} ${config.nas.backup.stateLocation}/audiobookshelf/ ${config.services.audiobookshelf.dataDir}
        '';
      };
    in
    [
      restore-audiobookshelf
      pkgs.rsync
    ];

  system.stateVersion = "23.11";
}
