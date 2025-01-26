{ config, ... }:
{
  options.backup.services.bazarr = config.lib.backup.mkBackupOption rec {
    name = "bazarr";
    serviceEnabled = config.services.bazarr.enable;
    dataDir = config.systemd.services.bazarr.serviceConfig.StateDirectory;
    backupDir = name;
    user = config.services.bazarr.user;
    group = config.services.bazarr.group;

    preBackup = ''
      systemctl stop ${config.systemd.services.bazarr.name}
    '';
    postBackup = ''
      systemctl start ${config.systemd.services.bazarr.name}
    '';
    preRestore = preBackup;
    postRestore = postBackup;
  };
}
