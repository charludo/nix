{ config, ... }:
{
  options.backup.services.minecraft-server = config.lib.backup.mkBackupOption rec {
    name = "minecraft-server";
    serviceEnabled = config.services.minecraft-server.enable;
    dataDir = config.services.minecraft-server.settings.global.database_path;
    backupDir = name;
    user = "minecraft";
    group = "minecraft";

    preBackup = ''
      systemctl stop ${config.systemd.services.minecraft-server.name}
    '';
    postBackup = ''
      systemctl start ${config.systemd.services.minecraft-server.name}
    '';
    preRestore = preBackup;
    postRestore = postBackup;
  };
}
