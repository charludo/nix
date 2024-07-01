{ pkgs, config, inputs, ... }:
{
  imports = [ ./_common.nix ];

  vm = {
    id = 3007;
    name = "SRV-GIT";

    hardware.cores = 2;
    hardware.memory = 2048;
    hardware.storage = "16G";

    networking.address = "192.168.30.30";
    networking.gateway = "192.168.30.1";
    networking.prefixLength = 24;

    networking.openPorts.tcp = [ 80 ];
    networking.openPorts.udp = [ 80 ];
  };

  users.users.git.group = "git";
  users.users.git.isNormalUser = true;
  users.groups.git = { };

  services.forgejo = {
    enable = true;
    database.type = "postgres";
    lfs.enable = true;
    settings = {
      server = rec {
        DOMAIN = "git.${inputs.private-settings.domains.ad}";
        ROOT_URL = "http://${DOMAIN}/";
        HTTP_PORT = 3000;
      };
      service.DISABLE_REGISTRATION = true;
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts.${config.services.forgejo.settings.server.DOMAIN} = {
      extraConfig = ''
        client_max_body_size 512M;
      '';
      locations."/".proxyPass = "http://localhost:${toString config.services.forgejo.settings.server.HTTP_PORT}";
    };
  };

  enableNasBackup = true;
  users.users.git.extraGroups = [ "nas" ];

  environment.systemPackages = [ pkgs.rsync ];
  systemd = {
    timers."git-backup-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "git-backup-daily.service";
      };
    };
    services."git-backup-daily" = {
      script = ''
        [ "$(stat -f -c %T /media/Backup)" == "smb2" ] && ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.forgejo.stateDir} /media/Backup/forgejo
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  system.stateVersion = "23.11";
}
