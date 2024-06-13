{ config, pkgs, lib, ... }:
{
  environment.systemPackages = [ pkgs.rsync ];

  systemd.services."rsync-media-backup" = lib.mkIf config.enableNas {
    enable = true;
    requires = [ "media-Media.mount" "media-NAS.mount" ];
    wantedBy = [ "multi-user.target" ];
    description = "Backup Media to NAS";
    script = ''
      [ "$(stat -f -c %T /media/NAS)" == "smb2" ] && ${pkgs.rsync}/bin/rsync -avz --delete --inplace /media/Media /media/NAS/CloudSync
    '';
  };

  systemd.timers."rsync-media-backup-hourly" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30min";
      OnUnitActiveSec = "1h";
      Unit = "rsync-media-backup.service";
    };
  };
}
