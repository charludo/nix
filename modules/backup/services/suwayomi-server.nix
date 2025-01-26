{ config, ... }:
{
  options.backup.services.suwayomi-server = config.lib.backup.mkBackupOption rec {
    name = "suwayomi-server";
    serviceEnabled = config.services.suwayomi-server.enable;
    dataDir = config.services.suwayomi-server.dataDir;
    backupDir = name;
    user = config.services.suwayomi-server.user;
    group = config.services.suwayomi-server.group;

    preBackup = ''
      systemctl stop ${config.systemd.services.suwayomi-server.name}
    '';
    postBackup = ''
      systemctl start ${config.systemd.services.suwayomi-server.name}
    '';
    preRestore = preBackup;
    postRestore = postBackup;
  };
}
