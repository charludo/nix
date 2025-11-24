{
  config,
  pkgs,
  private-settings,
  secrets,
  ...
}:
{
  vm = {
    id = 2208;
    name = "SRV-KAVITA";

    hardware.cores = 4;
    hardware.memory = 8192;
    hardware.storage = "16G";

    networking.nameservers = private-settings.upstreamDNS.ips;
    networking.openPorts.tcp = [ config.services.kavita.settings.Port ];
  };

  age.secrets.kavita-token.rekeyFile = secrets.kavita-token;

  services.kavita = {
    enable = true;
    tokenKeyFile = config.age.secrets.kavita-token.path;
    settings.IpAddresses = "0.0.0.0";
  };

  nas.enable = true;
  nas.backup.enable = true;
  nas.extraUsers = [ config.services.kavita.user ];

  systemd = {
    timers."kavita-backup-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "kavita-backup-daily.service";
      };
    };
    services."kavita-backup-daily" = {
      script = ''
        [ "$(stat -f -c %T ${config.nas.location})" != "smb2" ] && exit 1
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace --chown=${config.services.kavita.user}:* ${config.services.kavita.dataDir}/ ${config.nas.backup.stateLocation}/kavita
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  environment.systemPackages =
    let
      kavita-init = pkgs.writeShellApplication {
        name = "kavita-init";
        runtimeInputs = [ pkgs.rsync ];
        text = ''
          ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace --chown=${config.services.kavita.user}:* ${config.nas.backup.stateLocation}/kavita/ ${config.services.kavita.dataDir}
        '';
      };
    in
    [
      kavita-init
      pkgs.rsync
    ];
}
