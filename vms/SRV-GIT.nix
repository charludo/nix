{
  pkgs,
  config,
  private-settings,
  ...
}:
{
  imports = [ ./_common.nix ];

  vm = {
    id = 2212;
    name = "SRV-GIT";

    hardware.cores = 2;
    hardware.memory = 2048;
    hardware.storage = "16G";

    networking.openPorts.tcp = [ 80 ];
    networking.openPorts.udp = [ 80 ];
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
      service.DISABLE_REGISTRATION = true;
      repository = {
        "signing.DEFAULT_TRUST_MODEL" = "collaboratorcommitter";
      };
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts.${config.services.forgejo.settings.server.DOMAIN} = {
      extraConfig = ''
        client_max_body_size 512M;
      '';
      locations."/".proxyPass =
        "http://localhost:${toString config.services.forgejo.settings.server.HTTP_PORT}";
    };
  };

  nas.backup.enable = true;
  nas.extraUsers = [ config.services.forgejo.user ];

  services.fail2ban = {
    enable = true;
    maxretry = 1;
    bantime = "24h";
    bantime-increment = {
      enable = true;
      multipliers = "1 2 4 8 16 32 64";
      maxtime = "168h";
      overalljails = true;
    };
    jails = {
      sshd.settings = {
        enabled = true;
        filter = "sshd";
        action = "iptables-allports";
        maxretry = 1;
      };
      sshd-ddos.settings = {
        enabled = true;
        filter = "sshd-ddos";
        action = "iptables-allports";
        maxretry = 2;
      };
    };
  };

  environment.systemPackages =
    let
      restore-forgejo = pkgs.writeShellApplication {
        name = "restore-forgejo";
        runtimeInputs = [ pkgs.rsync ];
        text = ''
          ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.forgejo.user}:${config.services.forgejo.group} ${config.nas.backup.location}/forgejo/ ${config.services.forgejo.stateDir}
        '';
      };

      fail2ban-summary = pkgs.writeShellApplication {
        name = "fail2ban-summary";
        runtimeInputs = with pkgs; [
          fail2ban
          gnused
          jq
        ];
        text = ''
          fail2ban-client banned | sed "s/'/\"/g" | jq -r '.[] | keys[] as $jail | "\(.[$jail] | length) banned IPs in \($jail)"'
        '';
      };
    in
    [
      fail2ban-summary
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
