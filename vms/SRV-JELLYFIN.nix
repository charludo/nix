{ config, private-settings, ... }:
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

  nas.enable = true;
  nas.extraUsers = [ config.services.jellyfin.user ];

  nas.backup.enable = true;
  rsync."jellyfin" = {
    tasks = [
      {
        from = "${config.services.jellyfin.dataDir}";
        to = "${config.nas.backup.stateLocation}/jellyfin";
        chown = "${config.services.jellyfin.user}:${config.services.jellyfin.group}";
      }
    ];
  };
}
