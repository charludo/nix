{ lib, ... }:

with lib;

{
  imports = [
    ./rsync.nix
  ];

  config.lib.backup.mkBackupMechanism =
    mechanismConfig: with mechanismConfig; {
      enable = mkEnableOption "enable the ${name} backup mechanism";

      startAt = mkOption {
        type = with types; either str (listOf str);
        default = "daily";
        description = ''
          When or how often ${name} backups should run.
          Must be in the format described in {manpage}`systemd.time(7)`.
          If you do not want the backup to start automatically, use `[ ]`.
        '';
      };

      precedence = mkOption {
        type = types.int;
        default = 0;
        description = ''
          An integer value signifying the precedence, or "priority", of a backup mechanism.
          The lowest precedence backup not failing its `restoreCondition` check will be used to restore a backup.
        '';
      };

      extraPackages = mkOption {
        type = types.listOf types.path;
        default = extraPackages;
        description = "additional packages required by the ${name} backup mechanism";
      };

      backupScript = mkOption {
        type = types.functionTo types.str;
        default = backupScript;
        description = ''
          A nix expression which generates the bash script used to create ${name} backups.
          Receives a single argument of type set, where each set contains a `dataDir` key and a `backupDir` key,
          derived from the services for which backups are enabled.
        '';
        example =
          serviceConfig:
          "rsync -avz --stats --delete --inplace ${serviceConfig.dataDir}/ ${serviceConfig.backupDir}";
      };

      restoreScript = mkOption {
        type = types.functionTo types.str;
        default = restoreScript;
        description = ''
          A nix expression which generates the bash script used to restore ${name} backups.
          Receives a single argument of type set, where each set contains a `dataDir` key and a `backupDir` key, as well as the user and group for that service,
          derived from the services for which backups (and, by extension, restores) are enabled.
        '';
        example =
          serviceConfig:
          "rsync -avzI --stats --delete --inplace --chown ${serviceConfig.user}:${serviceConfig.group} ${serviceConfig.backupDir}/ ${serviceConfig.dataDir}";
      };

      backupCondition = mkOption {
        type = types.nullOr types.str;
        default = backupCondition;
        description = ''
          A bash expression which, if it returns a non-zero exit code, prevents ${name} backups from being created.
        '';
        example = ''
          [ "$(stat -f -c %T /path/to/NAS)" = "smb2" ] || exit 1
        '';
      };

      restoreCondition = mkOption {
        type = types.nullOr types.str;
        default = restoreCondition;
        description = ''
          A bash expression which, if it returns a non-zero exit code, prevents ${name} backups from being restored.
        '';
        example = ''
          [ "$(stat -f -c %T /path/to/NAS)" = "smb2" ] || exit 1
        '';
      };
    };
}
