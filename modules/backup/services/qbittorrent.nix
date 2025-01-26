{ config, ... }:
{
  options.backup.services.qbittorrent = config.lib.backup.mkBackupOption rec {
    name = "qbittorrent";
    serviceEnabled = config.services.qbittorrent.enable;
    dataDir = config.services.qbittorrent.dataDir;
    backupDir = name;
    user = config.services.qbittorrent.user;
    group = config.services.qbittorrent.group;

    preBackup = ''
      systemctl stop ${config.systemd.services.qbittorrent.name}
    '';
    postBackup = ''
      systemctl start ${config.systemd.services.qbittorrent.name}
    '';
    preRestore = preBackup;
    postRestore = postBackup;
  };
}
