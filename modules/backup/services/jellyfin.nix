{ config, ... }:
{
  options.backup.services.jellyfin = config.lib.backup.mkBackupOption rec {
    name = "jellyfin";
    serviceEnabled = config.services.jellyfin.enable;
    dataDir = config.services.jellyfin.dataDir;
    backupDir = name;
    user = config.services.jellyfin.user;
    group = config.services.jellyfin.group;

    preBackup = ''
      systemctl stop ${config.systemd.services.jellyfin.name}
    '';
    postBackup = ''
      systemctl start ${config.systemd.services.jellyfin.name}
    '';
    preRestore = preBackup;
    postRestore = postBackup;
  };
}
