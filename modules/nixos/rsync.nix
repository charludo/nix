{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.rsync;
in
{
  options.rsync = {
    enable = lib.mkEnableOption (lib.mdDoc "enable hourly backups to the NAS");
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.rsync ];

    systemd.services."rsync-media-backup" = lib.mkIf config.nas.enable {
      enable = true;
      requires = [ "media-Media.mount" "media-NAS.mount" ];
      wantedBy = [ "multi-user.target" ];
      description = "Backup Media to NAS";
      script = ''
        [ "$(stat -f -c %T ${config.nas.location})" == "smb2" ] && ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace /media/Media ${config.nas.location}/CloudSync
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
  };
}
