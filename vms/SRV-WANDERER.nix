{
  config,
  pkgs,
  private-settings,
  secrets,
  ...
}:
{
  vm = {
    id = 2220;
    name = "SRV-WANDERER";

    hardware.cores = 4;
    hardware.memory = 8192;
    hardware.storage = "32G";

    networking.openPorts.tcp = [ 8090 ];
  };

  age.secrets.wanderer-env.rekeyFile = secrets.wanderer-env;
  services.wanderer = {
    enable = true;
    package = pkgs.ours.wanderer;
    origin = "https://pathfinder.${private-settings.domains.home}";
    openFirewall = true;
    services.pocketbase.url = "http://0.0.0.0:8090";
    secretsFile = config.age.secrets.wanderer-env.path;
  };

  nas.backup.enable = true;
  nas.extraUsers = [ config.services.wanderer.user ];

  systemd = {
    timers."wanderer-backup-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "wanderer-backup-daily.service";
      };
    };
    services."wanderer-backup-daily" = {
      script = ''
        [ "$(stat -f -c %T ${config.nas.location})" != "smb2" ] && exit 1
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace --chown=${config.services.wanderer.user}:* /var/lib/wanderer/ ${config.nas.backup.stateLocation}/wanderer
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  environment.systemPackages =
    let
      wanderer-init = pkgs.writeShellApplication {
        name = "wanderer-init";
        runtimeInputs = [ pkgs.rsync ];
        text = ''
          ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace --chown=${config.services.wanderer.user}:* ${config.nas.backup.stateLocation}/wanderer/ /var/lib/wanderer
        '';
      };
    in
    [
      wanderer-init
      pkgs.rsync
    ];
}
