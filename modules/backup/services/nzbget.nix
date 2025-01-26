{ config, ... }:
{
  options.backup.services.nzbget = config.lib.backup.mkBackupOption rec {
    name = "nzbget";
    serviceEnabled = config.services.nzbget.enable;
    dataDir = config.systemd.services.nzbget.serviceConfig.StateDirectory;
    backupDir = name;
    user = config.services.nzbget.user;
    group = config.services.nzbget.group;

    preBackup = ''
      systemctl stop ${config.systemd.services.nzbget.name}
    '';
    postBackup = ''
      systemctl start ${config.systemd.services.nzbget.name}
    '';
    preRestore = preBackup;
    postRestore = postBackup;
  };
}
