{ config, ... }:
{
  options.backup.services.readarr = config.lib.backup.mkBackupOption rec {
    name = "readarr";
    serviceEnabled = config.services.readarr.enable;
    dataDir = config.services.readarr.dataDir;
    backupDir = name;
    user = config.services.readarr.user;
    group = config.services.readarr.group;

    preBackup = ''
      systemctl stop ${config.systemd.services.readarr.name}
    '';
    postBackup = ''
      systemctl start ${config.systemd.services.readarr.name}
    '';
    preRestore = preBackup;
    postRestore = postBackup;
  };
}
