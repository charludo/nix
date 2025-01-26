{ config, ... }:
{
  options.backup.services.lidarr = config.lib.backup.mkBackupOption rec {
    name = "lidarr";
    serviceEnabled = config.services.lidarr.enable;
    dataDir = config.services.lidarr.dataDir;
    backupDir = name;
    user = config.services.lidarr.user;
    group = config.services.lidarr.group;

    preBackup = ''
      systemctl stop ${config.systemd.services.lidarr.name}
    '';
    postBackup = ''
      systemctl start ${config.systemd.services.lidarr.name}
    '';
    preRestore = preBackup;
    postRestore = postBackup;
  };
}
