{ config, ... }:
{
  options.backup.services.prowlarr = config.lib.backup.mkBackupOption rec {
    name = "prowlarr";
    serviceEnabled = config.services.prowlarr.enable;
    dataDir = "/var/lib/prowlarr";
    backupDir = name;
    user = "prowlarr";
    group = "prowlarr";

    preBackup = ''
      systemctl stop ${config.systemd.services.prowlarr.name}
    '';
    postBackup = ''
      systemctl start ${config.systemd.services.prowlarr.name}
    '';
    preRestore = preBackup;
    postRestore = postBackup;
  };
}
