{
  inputs,
  config,
  secrets,
  ...
}:
{
  imports = [ inputs.authentik.nixosModules.default ];

  vm = {
    id = 2004;
    name = "SRV-AUTHENTIK";

    hardware.cores = 2;
    hardware.memory = 2048;
    hardware.storage = "8G";

    networking.openPorts.tcp = [
      9443
      9000
    ];
    networking.openPorts.udp = [
      9443
      9000
    ];
  };

  age.secrets.authentik.rekeyFile = secrets.authentik;
  services.authentik = {
    enable = true;
    environmentFile = config.age.secrets.authentik.path;
    settings = {
      disable_startup_analytics = true;
      disable_update_check = true;
      disable_error_reporting__enabled = false;
      avatars = "initials";
    };
  };
  nas.backup.enable = true;
  services.postgresqlBackup = {
    enable = true;
    databases = config.services.postgresql.ensureDatabases;
    location = "${config.nas.backup.location}/authentik";
  };

  system.stateVersion = "23.11";
}
