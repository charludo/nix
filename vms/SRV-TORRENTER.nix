{
  config,
  pkgs,
  inputs,
  secrets,
  ...
}:
let
  restore-torrenter = pkgs.writeShellApplication {
    name = "restore-torrenter";
    runtimeInputs = [ pkgs.rsync ];
    text = ''
      ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.sonarr.user}:${config.services.sonarr.group} ${config.nas.backup.stateLocation}/torrenter/sonarr/ ${config.services.sonarr.dataDir}
      ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.radarr.user}:${config.services.radarr.group} ${config.nas.backup.stateLocation}/torrenter/radarr/ ${config.services.radarr.dataDir}
      ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.lidarr.user}:${config.services.lidarr.group} ${config.nas.backup.stateLocation}/torrenter/lidarr/ ${config.services.lidarr.dataDir}
      ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.readarr.user}:${config.services.readarr.group} ${config.nas.backup.stateLocation}/torrenter/readarr/ ${config.services.readarr.dataDir}
      ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown prowlarr:prowlarr ${config.nas.backup.stateLocation}/torrenter/prowlarr/ /var/lib/prowlarr
      ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.qbittorrent.user}:${config.services.qbittorrent.group} ${config.nas.backup.stateLocation}/torrenter/qbittorrent/ ${config.services.qbittorrent.profileDir}
    '';
  };
in
{
  vm = {
    id = 2101;
    name = "SRV-TORRENTER";
    runOnGPUHost = true;

    hardware.cores = 4;
    hardware.memory = 24576;
    hardware.storage = "128G";

    certsFor = [
      {
        name = "sonarr";
        port = config.services.sonarr.settings.server.port;
      }
      {
        name = "radarr";
        port = config.services.radarr.settings.server.port;
      }
      {
        name = "lidarr";
        port = config.services.lidarr.settings.server.port;
      }
      {
        name = "readarr-audio";
        port = config.services.readarr.settings.server.port;
      }
      {
        name = "prowlarr";
        port = config.services.prowlarr.settings.server.port;
      }
      {
        name = "qbittorrent";
        port = config.services.qbittorrent.webuiPort;
      }
      {
        name = "nzbget";
        port = 6789;
      }
      {
        name = "idagio";
        port = config.services.idagio.port;
      }
    ];
  };

  surfshark = {
    enable = true;
    alwaysOn = true;
    hopWeekly = true;
    iptables = {
      enable = true;
      enforceForUsers = [
        config.services.nzbget.user
        config.services.qbittorrent.user
      ];
    };
  };
  # In the nixpkgs module, qbittorrent is not assigned a gid, which is required for our iptables rules.
  users.groups.${config.services.qbittorrent.group}.gid = 84;

  networking.firewall.interfaces.enp6s18.allowedTCPPorts = [ 6789 ]; # NZBGet web interface
  networking.interfaces.enp6s18.ipv4.routes = [
    {
      address = "192.168.0.0";
      prefixLength = 16;
      via = config.vm.networking.gateway;
    }
  ];

  services = {
    sonarr.enable = true;
    sonarr.openFirewall = true;

    radarr.enable = true;
    radarr.openFirewall = true;

    lidarr.enable = true;
    lidarr.openFirewall = true;

    readarr.enable = true;
    readarr.openFirewall = true;

    prowlarr.enable = true;
    prowlarr.openFirewall = true;

    qbittorrent.enable = true;
    qbittorrent.openFirewall = true;
    qbittorrent.webuiPort = 8112;
    qbittorrent.profileDir = "/var/lib/qbittorrent";

    nzbget.enable = true;

    idagio.enable = true;
    idagio.openFirewall = true;
    idagio.configLocation = config.age.secrets.idagio.path;
    idagio.package = inputs.idagio.packages.x86_64-linux.default;
  };

  # NZBGet scripts require python
  nixpkgs.overlays = [
    (_final: prev: {
      nzbget = prev.nzbget.overrideAttrs (old: {
        buildInputs = old.buildInputs ++ [ pkgs.python313 ];
      });
    })
  ];

  nas.enable = true;
  nas.backup.enable = true;
  nas.extraUsers = [
    config.services.sonarr.user
    config.services.radarr.user
    config.services.lidarr.user
    config.services.readarr.user
    config.services.qbittorrent.user
    config.services.nzbget.user
  ];

  age.secrets.nzbget = {
    rekeyFile = secrets.torrenter-nzbget;
    owner = config.services.nzbget.user;
    path = "/var/lib/nzbget/nzbget.conf";
  };

  age.secrets.idagio = {
    rekeyFile = secrets.torrenter-idagio;
    mode = "0444";
  };

  environment.systemPackages = [
    restore-torrenter
    pkgs.ours.remux
  ];

  systemd = {
    # Ensure qbittorrent/nzbget only start AFTER a VPN connection has been established, and the NAS is mounted for *arr
    services.nzbget.bindsTo = [
      "sys-devices-virtual-net-tun0.device"
      "media-NAS.mount"
    ];
    services.nzbget.after = [
      "sys-devices-virtual-net-tun0.device"
      "media-NAS.mount"
    ];
    services.nzbget.partOf = [
      "sys-devices-virtual-net-tun0.device"
      "media-NAS.mount"
    ];
    services.nzbget.path = [ pkgs.python313 ];
    services.qbittorrent.bindsTo = [
      "sys-devices-virtual-net-tun0.device"
      "media-NAS.mount"
    ];
    services.qbittorrent.after = [
      "sys-devices-virtual-net-tun0.device"
      "media-NAS.mount"
    ];
    services.qbittorrent.partOf = [
      "sys-devices-virtual-net-tun0.device"
      "media-NAS.mount"
    ];
    services.sonarr.after = [ "media-NAS.mount" ];
    services.radarr.after = [ "media-NAS.mount" ];
    services.lidarr.after = [ "media-NAS.mount" ];
    services.readarr.after = [ "media-NAS.mount" ];
    services.prowlarr.after = [ "media-NAS.mount" ];

    timers."torrenter-backup-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "torrenter-backup-daily.service";
      };
    };
    services."torrenter-backup-daily" = {
      script = ''
        [ "$(stat -f -c %T ${config.nas.backup.stateLocation})" != "smb2" ] && exit 1
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.sonarr.dataDir}/ ${config.nas.backup.stateLocation}/torrenter/sonarr
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.radarr.dataDir}/ ${config.nas.backup.stateLocation}/torrenter/radarr
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.lidarr.dataDir}/ ${config.nas.backup.stateLocation}/torrenter/lidarr
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.readarr.dataDir}/ ${config.nas.backup.stateLocation}/torrenter/readarr
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace /var/lib/prowlarr/ ${config.nas.backup.stateLocation}/torrenter/prowlarr
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.qbittorrent.profileDir}/ ${config.nas.backup.stateLocation}/torrenter/qbittorrent
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  system.stateVersion = "23.11";
}
