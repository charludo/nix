{
  config,
  pkgs,
  secrets,
  ...
}:
{
  vm = {
    id = 2101;
    name = "SRV-TORRENTER";
    runOnGPUHost = true;

    hardware.cores = 4;
    hardware.memory = 24576;
    hardware.storage = "256G";

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
    idagio.package = pkgs.ours.idagio;
  };

  nas.enable = true;
  nas.extraUsers = [
    config.services.sonarr.user
    config.services.radarr.user
    config.services.lidarr.user
    config.services.readarr.user
    config.services.qbittorrent.user
    config.services.nzbget.user
  ];

  nas.backup.enable = true;
  rsync."torrenter" = {
    tasks = [
      {
        from = "${config.services.sonarr.dataDir}";
        to = "${config.nas.backup.stateLocation}/torrenter/sonarr";
        chown = "${config.services.sonarr.user}:${config.services.sonarr.group}";
      }
      {
        from = "${config.services.radarr.dataDir}";
        to = "${config.nas.backup.stateLocation}/torrenter/radarr";
        chown = "${config.services.radarr.user}:${config.services.radarr.group}";
      }
      {
        from = "${config.services.lidarr.dataDir}";
        to = "${config.nas.backup.stateLocation}/torrenter/lidarr";
        chown = "${config.services.lidarr.user}:${config.services.lidarr.group}";
      }
      {
        from = "${config.services.readarr.dataDir}";
        to = "${config.nas.backup.stateLocation}/torrenter/readarr";
        chown = "${config.services.readarr.user}:${config.services.readarr.group}";
      }
      {
        from = "/var/lib/prowlarr";
        to = "${config.nas.backup.stateLocation}/torrenter/prowlarr";
        chown = "prowlarr:prowlarr";
      }
      {
        from = "${config.services.qbittorrent.profileDir}";
        to = "${config.nas.backup.stateLocation}/torrenter/qbittorrent";
        chown = "${config.services.qbittorrent.user}:${config.services.qbittorrent.group}";
      }
    ];
  };

  age.secrets.nzbget = {
    rekeyFile = secrets.torrenter-nzbget;
    owner = config.services.nzbget.user;
    path = "/var/lib/nzbget/nzbget.conf";
  };

  age.secrets.idagio = {
    rekeyFile = secrets.torrenter-idagio;
    mode = "0444";
  };

  environment.systemPackages = [ pkgs.ours.remux ];

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

    # NzbGet and qBittorrent die when tun0 / the NAS become unavailable, but do not come back up.
    # This is an ugly workaround to ensure they are never down for long.
    timers."nzbget" = {
      wantedBy = [ "timers.target" ];
      requires = [
        "sys-devices-virtual-net-tun0.device"
        "media-NAS.mount"
      ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
    };
    timers."qbittorrent" = {
      wantedBy = [ "timers.target" ];
      requires = [
        "sys-devices-virtual-net-tun0.device"
        "media-NAS.mount"
      ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
    };

    services.sonarr.after = [ "media-NAS.mount" ];
    services.radarr.after = [ "media-NAS.mount" ];
    services.lidarr.after = [ "media-NAS.mount" ];
    services.readarr.after = [ "media-NAS.mount" ];
    services.prowlarr.after = [ "media-NAS.mount" ];
  };
}
