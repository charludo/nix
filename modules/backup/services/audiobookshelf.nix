{ config, ... }:
{
  options.backup.services.audiobookshelf = config.lib.backup.mkBackupOption rec {
    name = "audiobookshelf";
    serviceEnabled = config.services.audiobookshelf.enable;
    dataDir = config.services.audiobookshelf.dataDir;
    backupDir = name;
    user = config.services.audiobookshelf.user;
    group = config.services.audiobookshelf.group;

    preBackup = ''
      systemctl stop ${config.systemd.services.audiobookshelf.name}
    '';
    postBackup = ''
      systemctl start ${config.systemd.services.audiobookshelf.name}
    '';
    preRestore = preBackup;
    postRestore = postBackup;
  };
}
