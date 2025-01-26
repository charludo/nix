{ config, ... }:
{
  options.backup.services.paperless = config.lib.backup.mkBackupOption rec {
    name = "paperless";
    serviceEnabled = config.services.paperless.enable;
    dataDir = config.services.paperless.dataDir;
    backupDir = name;
    user = config.services.paperless.user;
    group = user;

    preBackup = ''
      systemctl stop ${config.systemd.services.paperless-web.name}
      systemctl stop ${config.systemd.services.paperless-consumer.name}
      systemctl stop ${config.systemd.services.paperless-task-queue.name}
    '';
    postBackup = ''
      systemctl start ${config.systemd.services.paperless-task-queue.name}
      systemctl start ${config.systemd.services.paperless-consumer.name}
      systemctl start ${config.systemd.services.paperless-web.name}
    '';
    preRestore = preBackup;
    postRestore = postBackup;
  };
}
