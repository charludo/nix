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
    hardware.memory = 16384;
    hardware.storage = "64G";

    networking.nameservers = private-settings.upstreamDNS;
    requiresGPU = true;
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

  users.users."${config.services.jellyfin.user}".extraGroups = [
    "render"
    "video"
    "input"
  ];
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      vaapiVdpau
      libvdpau-va-gl
      intel-compute-runtime
      vpl-gpu-rt
    ];
  };
  hardware.firmware = [ pkgs.linux-firmware ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.blacklistedKernelModules = [ "i915" ];
  boot.kernelParams = [
    "i915.enable_guc=2"
    "module_blacklist=i915"
    "xe.force_probe=7d51"
    "i915.force_probe=!7d51"
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
