{ pkgs, config, ... }:
{
  imports = [ ./_common.nix ];

  vm = {
    id = 2207;
    name = "SRV-AUDIOBOOKSHELF";

    hardware.cores = 4;
    hardware.memory = 16384;
    hardware.storage = "32G";

    networking.nameservers = [ "1.1.1.1" ];
  };

  services.audiobookshelf = {
    enable = true;
    openFirewall = true;
    host = "0.0.0.0";
  };

  enableNas = true;
  enableNasBackup = true;
  users.users."${config.services.audiobookshelf.user}".extraGroups = [ "nas" ];

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
        [ "$(stat -f -c %T /media/Backup)" == "smb2" ] && ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.audiobookshelf.dataDir}/ /media/Backup/audiobookshelf
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
          ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.audiobookshelf.user}:${config.services.audiobookshelf.group} /media/Backup/audiobookshelf/ ${config.services.audiobookshelf.dataDir}
        '';
      };
    in
    [ restore-audiobookshelf pkgs.rsync ];

  system.stateVersion = "23.11";
}
