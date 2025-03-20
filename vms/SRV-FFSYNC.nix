{
  config,
  pkgs,
  private-settings,
  secrets,
  ...
}:
{
  vm = {
    id = 2215;
    name = "SRV-FFSYNC";

    hardware.cores = 2;
    hardware.memory = 2048;
    hardware.storage = "16G";

    runOnSecondHost = true;
    networking.openPorts.tcp = [ config.services.firefox-syncserver.settings.port ];
    networking.openPorts.udp = [ config.services.firefox-syncserver.settings.port ];
  };

  age.secrets.ffsync.rekeyFile = secrets.ffsync;
  services.firefox-syncserver = {
    enable = true;
    secrets = config.age.secrets.ffsync.path;
    settings.host = "0.0.0.0";

    singleNode = {
      enable = true;
      capacity = 2;
      hostname = "0.0.0.0";
      url = "https://ffsync.${private-settings.domains.home}";
    };
  };

  nas.backup.enable = true;
  services.mysql.package = pkgs.mariadb;
  services.mysqlBackup = {
    enable = true;
    databases = config.services.mysql.ensureDatabases;
    location = "${config.nas.backup.location}/ffsync";
  };

  system.stateVersion = "23.11";
}
