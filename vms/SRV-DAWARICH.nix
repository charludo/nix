{
  config,
  lib,
  private-settings,
  secrets,
  ...
}:
{
  vm = {
    id = 2225;
    name = "SRV-DAWARICH";

    hardware.cores = 4;
    hardware.memory = 4096;
    hardware.storage = "32G";

    networking.openPorts.tcp = [ 80 ];
  };

  services.dawarich = {
    enable = true;
    localDomain = "dawarich.${private-settings.domains.home}";
    configureNginx = true;
    environment = {
      APPLICATION_PROTOCOL = "https";
    };

    secretKeyBaseFile = config.age.secrets.dawarich.path;
  };
  age.secrets.dawarich.rekeyFile = secrets.dawarich;

  services.nginx.virtualHosts.${config.services.dawarich.localDomain}.locations."@proxy" = {
    recommendedProxySettings = lib.mkForce false;
    extraConfig = ''
      proxy_set_header        Host $host;
      proxy_set_header        X-Real-IP $remote_addr;
      proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header        X-Forwarded-Proto https;
      proxy_set_header        X-Forwarded-Host $host;
      proxy_set_header        X-Forwarded-Server $hostname;
    '';
  };

  services.postgresqlBackup = {
    enable = true;
    databases = [ config.services.dawarich.database.name ];
    startAt = "*-*-* 02:00:00";
  };

  nas.backup.enable = true;
  rsync."dawarich" = {
    tasks = [
      {
        from = "/var/lib/dawarich";
        to = "${config.nas.backup.stateLocation}/dawarich/dawarich";
        chown = "${config.services.dawarich.user}:${config.services.dawarich.group}";
      }
      {
        from = config.services.postgresqlBackup.location;
        to = "${config.nas.backup.stateLocation}/dawarich/postgres";
        chown = "postgres:postgres";
      }
    ];
    timerConfig = {
      OnCalendar = "*-*-* 02:15:00";
      Persistent = true;
    };
  };
}
