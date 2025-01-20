{ config, lib, ... }:

with lib;

{
  options.services.paperless.backup = {
    enable = mkEnableOption (lib.mdDoc "enable backups for paperless");

    from = mkOption {
      type = types.str;
      default = config.services.paperless.dataDir;
    };

    to = mkOption {
      type = types.str;
      default = "${config.services.backup.backupDir}/paperless";
    };

    user = mkOption {
      type = types.str;
      default = config.services.paperless.user;
    };

    group = mkOption {
      type = types.str;
      default = config.services.paperless.group;
    };

    preAction = mkOption {
      type = types.str;
      default = ''
        systemctl stop ${config.systemd.services.paperless-web.name}
        systemctl stop ${config.systemd.services.paperless-consumer.name}
        systemctl stop ${config.systemd.services.paperless-task-queue.name}
      '';
    };
    postAction = mkOption {
      type = types.str;
      default = ''
        systemctl stop ${config.systemd.services.paperless-task-queue.name}
        systemctl stop ${config.systemd.services.paperless-consumer.name}
        systemctl stop ${config.systemd.services.paperless-web.name}
      '';
    };
  };

  config = mkIf config.services.backup.enable && config.services.paperless.enable && (config.services.paperless.backup.enable || config.services.backup.autoEnable) {
    services.backup.activeTargets.paperless = config.services.backup.targets.paperless;
  };
}
