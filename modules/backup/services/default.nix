{ config, lib, ... }:

with lib;

let
  cfg = config.services.backup;
in
{
  config.lib.backup.mkBackupOption =
    serviceConfig: with serviceConfig; {
      enable = mkEnableOption "enable backups for ${name}" // rec {
        default = cfg.enable && cfg.autoEnable && serviceEnabled;
        defaultText = literalMD "same as [`services.backup.autoEnable`](#servicesbackupautoenable)";
        example = !default;
      };

      mechanisms = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = mkDoc ''
          Only create backups of ${name} for the specified backup mechanisms.
          If `null`, enable all configured mechanisms.
        '';
      };

      dataDir = mkOption {
        type = types.str;
        default = dataDir;
        description = "location of ${name} files to backup";
      };

      backupDir = mkOption {
        type = types.str;
        default = backupDir;
        description = "location where ${name} files should be backed up to";
      };

      user = mkOption {
        type = types.str;
        default = user;
        description = "user whom ${name} files belong to";
      };

      group = mkOption {
        type = types.str;
        default = group;
        description = "group whom ${name} files belong to";
      };

      preBackup = mkOption {
        type = types.str;
        default = preBackup;
        description = "action to perform before ${name} files are backup up";
      };

      postBackup = mkOption {
        type = types.str;
        default = postBackup;
        description = "action to perform after ${name} files are backup up";
      };

      preRestore = mkOption {
        type = types.str;
        default = preRestore;
        description = "action to perform baefore ${name} files are restored";
      };

      postRestore = mkOption {
        type = types.str;
        default = postRestore;
        description = "action to perform after ${name} files are restored";
      };
    };
}
