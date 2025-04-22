{
  pkgs,
  config,
  private-settings,
  ...
}:
{
  vm = {
    id = 2212;
    name = "SRV-GIT";

    hardware.cores = 2;
    hardware.memory = 2048;
    hardware.storage = "16G";

    networking.openPorts.tcp = [ config.services.forgejo.settings.server.HTTP_PORT ];
    networking.openPorts.udp = [ config.services.forgejo.settings.server.HTTP_PORT ];
  };

  users.users.git.group = "git";
  users.users.git.isNormalUser = true;
  users.groups.git = { };

  services.forgejo = {
    enable = true;
    package = pkgs.forgejo;
    database.type = "postgres";
    lfs.enable = true;
    settings = {
      server = rec {
        DOMAIN = "git.${private-settings.domains.home}";
        ROOT_URL = "https://${DOMAIN}/";
        HTTP_PORT = 3000;
      };
      cors = {
        ENABLED = true;
        ALLOW_DOMAIN = builtins.concatStringsSep ", " [
          "https://*.${private-settings.domains.home}"
          "https://*.${private-settings.domains.personal}"
          "https://*.${private-settings.domains.blog}"
        ];
      };
      service.DISABLE_REGISTRATION = true;
      repository = {
        "signing.DEFAULT_TRUST_MODEL" = "collaboratorcommitter";
      };
    };
  };

  nas.backup.enable = true;
  nas.extraUsers = [ config.services.forgejo.user ];

  fail2ban.enable = true;
  fail2ban.doNotBan = [ "192.168.0.0/16" ];

  environment.systemPackages =
    let
      restore-forgejo = pkgs.writeShellApplication {
        name = "restore-forgejo";
        runtimeInputs = [ pkgs.rsync ];
        text = ''
          ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.forgejo.user}:${config.services.forgejo.group} ${config.nas.backup.location}/forgejo/ ${config.services.forgejo.stateDir}
        '';
      };
    in
    [
      restore-forgejo
      pkgs.rsync
    ];
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
        [ "$(stat -f -c %T ${config.nas.backup.location})" == "smb2" ] && ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.forgejo.stateDir}/ ${config.nas.backup.location}/forgejo
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  system.stateVersion = "23.11";
}
