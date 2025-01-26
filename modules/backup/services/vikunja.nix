{ config, ... }:
{
  options.backup.services.vikunja = config.lib.backup.mkBackupOption rec {
    name = "vikunja";
    serviceEnabled = config.services.vikunja.enable;
    dataDir = config.services.vikunja.settings.global.database_path;
    backupDir = name;
    user = "vikunja";
    group = "vikunja";

    preBackup = ''
      systemctl stop ${config.systemd.services.vikunja.name}
    '';
    postBackup = ''
      systemctl start ${config.systemd.services.vikunja.name}
    '';
    preRestore = preBackup;
    postRestore = postBackup;
  };
}
