{
  pkgs,
  config,
  private-settings,
  ...
}:
{
  vm = {
    id = 2201;
    name = "SRV-JELLYFIN";

    hardware.cores = 4;
    hardware.memory = 32768;
    hardware.storage = "64G";
    hardware.gpu.enable = true;

    networking.nameservers = private-settings.upstreamDNS.ips;
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

  nixpkgs.overlays = [
    (_final: prev: {
      jellyfin-ffmpeg = prev.jellyfin-ffmpeg.override {
        # Exact version of ffmpeg_* depends on what jellyfin-ffmpeg package is using.
        # In 24.11 it's ffmpeg_7-full.
        # See jellyfin-ffmpeg package source for details
        ffmpeg_7-full = prev.ffmpeg_7-full.override {
          withMfx = false;
          withVpl = true;
          withUnfree = true;
        };
      };
    })
  ];

  users.users."${config.services.jellyfin.user}".extraGroups = [
    "render"
    "video"
    "input"
  ];

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
        [ "$(stat -f -c %T ${config.nas.backup.stateLocation})" == "smb2" ] && ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.jellyfin.dataDir}/ ${config.nas.backup.stateLocation}/jellyfin
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
          ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.jellyfin.user}:${config.services.jellyfin.group} ${config.nas.backup.stateLocation}/jellyfin/ ${config.services.jellyfin.dataDir}
        '';
      };
    in
    [
      restore-jellyfin
      pkgs.rsync
    ];

  system.stateVersion = "23.11";
}
