{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.backup.mechanisms.rsync;
in
{
  options.backup.mechanisms.rsync =
    config.lib.backup.mkBackupMechanism rec {
      name = "rsync";
      startAt = "daily";
      extraPackages = [ pkgs.rsync ];

      backupScript = serviceConfig: ''
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${serviceConfig.dataDir}/ ${cfg.backupRootDir}/${serviceConfig.backupDir}
      '';
      restoreScript = serviceConfig: ''
        "${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${serviceConfig.user}:${serviceConfig.group} ${cfg.backupRootDir}/${serviceConfig.backupDir}/ ${serviceConfig.dataDir}"
      '';

      backupCondition = ''
        [ "$(stat -f -c %T /path/to/NAS)" = "smb2" ] || exit 1
      '';
      restoreCondition = backupCondition;
    }
    // {
      backupRootDir = mkOption {
        type = types.str;
        description = "root dir under which backup targets live";
        example = "/media/Backup";
      };
    };
}
