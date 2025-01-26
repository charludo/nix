{ config, ... }:
{
  options.backup.services.kavita = config.lib.backup.mkBackupOption rec {
    name = "kavita";
    serviceEnabled = config.services.kavita.enable;
    dataDir = config.services.kavita.dataDir;
    backupDir = name;
    user = config.services.kavita.user;
    group = "*";

    preBackup = ''
      systemctl stop ${config.systemd.services.kavita.name}
    '';
    postBackup = ''
      systemctl start ${config.systemd.services.kavita.name}
    '';
    preRestore = preBackup;
    postRestore = postBackup;
  };
}
