{ config, ... }:
{
  options.backup.services.radarr = config.lib.backup.mkBackupOption rec {
    name = "radarr";
    serviceEnabled = config.services.radarr.enable;
    dataDir = config.services.radarr.dataDir;
    backupDir = name;
    user = config.services.radarr.user;
    group = config.services.radarr.group;

    preBackup = ''
      systemctl stop ${config.systemd.services.radarr.name}
    '';
    postBackup = ''
      systemctl start ${config.systemd.services.radarr.name}
    '';
    preRestore = preBackup;
    postRestore = postBackup;
  };
}
