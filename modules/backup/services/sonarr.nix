{ config, ... }:
{
  options.backup.services.sonarr = config.lib.backup.mkBackupOption rec {
    name = "sonarr";
    serviceEnabled = config.services.sonarr.enable;
    dataDir = config.services.sonarr.dataDir;
    backupDir = name;
    user = config.services.sonarr.user;
    group = config.services.sonarr.group;

    preBackup = ''
      systemctl stop ${config.systemd.services.sonarr.name}
    '';
    postBackup = ''
      systemctl start ${config.systemd.services.sonarr.name}
    '';
    preRestore = preBackup;
    postRestore = postBackup;
  };
}
