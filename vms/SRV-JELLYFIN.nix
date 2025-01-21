{ pkgs, config, ... }:
{
  imports = [ ./_common.nix ];

  vm = {
    id = 2201;
    name = "SRV-JELLYFIN";

    hardware.cores = 4;
    hardware.memory = 16384;
    hardware.storage = "32G";

    networking.nameservers = [ "1.1.1.1" ];
  };

  services.jellyfin = rec {
    enable = true;
    openFirewall = true;
    dataDir = "/var/lib/jellyfin";
    configDir = "${dataDir}/config";
    logDir = "${dataDir}/log";
    cacheDir = "${dataDir}/cache";
  };

  nas.enable = true;
  nas.backup.enable = true;
  nas.extraUsers = [ config.services.jellyfin.user ];

  systemd = {
    timers."jellyfin-backup-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "jellyfin-backup-daily.service";
      };
    };
    services."jellyfin-backup-daily" = {
      script = ''
        [ "$(stat -f -c %T ${config.nas.backup.location})" == "smb2" ] && ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.jellyfin.dataDir}/ ${config.nas.backup.location}/jellyfin
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  environment.systemPackages =
    let
      restore-jellyfin = pkgs.writeShellApplication {
        name = "restore-jellyfin";
        runtimeInputs = [ pkgs.rsync ];
        text = ''
          ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.jellyfin.user}:${config.services.jellyfin.group} ${config.nas.backup.location}/jellyfin/ ${config.services.jellyfin.dataDir}
        '';
      };
    in
    [
      restore-jellyfin
      pkgs.rsync
    ];

  system.stateVersion = "23.11";
}
