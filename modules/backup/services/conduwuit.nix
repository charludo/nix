{ config, ... }:
{
  options.backup.services.conduwuit = config.lib.backup.mkBackupOption rec {
    name = "conduwuit";
    serviceEnabled = config.services.conduwuit.enable;
    dataDir = config.services.conduwuit.settings.global.database_path;
    backupDir = name;
    user = config.services.conduwuit.user;
    group = config.services.conduwuit.group;

    preBackup = ''
      systemctl stop ${config.systemd.services.conduwuit.name}
    '';
    postBackup = ''
      systemctl start ${config.systemd.services.conduwuit.name}
    '';
    preRestore = preBackup;
    postRestore = postBackup;
  };
}
