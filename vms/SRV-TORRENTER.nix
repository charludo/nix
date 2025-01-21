{
  config,
  pkgs,
  lib,
  inputs,
  secrets,
  ...
}:
let
  restore-torrenter = pkgs.writeShellApplication {
    name = "restore-torrenter";
    runtimeInputs = [ pkgs.rsync ];
    text = ''
      ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.sonarr.user}:${config.services.sonarr.group} ${config.nas.backup.location}/torrenter/sonarr/ ${config.services.sonarr.dataDir}
      ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.radarr.user}:${config.services.radarr.group} ${config.nas.backup.location}/torrenter/radarr/ ${config.services.radarr.dataDir}
      ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.lidarr.user}:${config.services.lidarr.group} ${config.nas.backup.location}/torrenter/lidarr/ ${config.services.lidarr.dataDir}
      ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.readarr.user}:${config.services.readarr.group} ${config.nas.backup.location}/torrenter/readarr/ ${config.services.readarr.dataDir}
      ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown prowlarr:prowlarr ${config.nas.backup.location}/torrenter/prowlarr/ /var/lib/prowlarr
      ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.qbittorrent.user}:${config.services.qbittorrent.group} ${config.nas.backup.location}/torrenter/qbittorrent/ ${config.services.qbittorrent.dataDir}
    '';
    # ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.bazarr.user}:${config.services.bazarr.group} ${config.nas.backup.location}/torrenter/bazarr/ /var/lib/bazarr
  };
  get-anime-music = pkgs.writeShellApplication {
    name = "get-anime-music";
    runtimeInputs = [
      pkgs.yt-dlp
      pkgs.coreutils
      pkgs.ffmpeg
    ];
    text = ''
      url="$(cat ${config.sops.secrets.anime-playlist.path})"
      target="${config.nas.location}/Musik/Anime"

      yt-dlp --verbose --cookies "''${target}/cookies.txt" \
      --yes-playlist --format "bestaudio" -o "''${target}/%(title)s.%(ext)s" \
      --extract-audio --audio-format "best" --audio-quality 192K \
      --add-metadata --postprocessor-args "-metadata artist=Anime\ Playlist -metadata album=Anime\ Playlist -metadata genre=Soundtrack -metadata album_artist=Various\ Artists -metadata synopsis=''' -metadata description='''" \
      --download-archive "''${target}/archive.txt" "$url"
    '';
  };
in
{
  imports = [
    ./_common.nix
  ];

  nixpkgs.config.permittedInsecurePackages = [
    "dotnet-sdk-6.0.428"
    "aspnetcore-runtime-6.0.36"
  ];

  vm = {
    id = 2101;
    name = "SRV-TORRENTER";

    hardware.cores = 4;
    hardware.memory = 24576;
    hardware.storage = "4G"; # expand to 128G - not enough ram to do so directly lol

    networking.nameservers = [ "1.1.1.1" ];
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

  networking.firewall.interfaces.ens18.allowedTCPPorts = [ 6789 ]; # NZBGet web interface
  networking.interfaces.ens18.ipv4.routes = [
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

    # bazarr.enable = true;
    # bazarr.openFirewall = true;

    prowlarr.enable = true;
    prowlarr.openFirewall = true;

    qbittorrent.enable = true;
    qbittorrent.openFirewall = true;

    nzbget.enable = true;

    idagio.enable = true;
    idagio.openFirewall = true;
    idagio.host = config.vm.networking.address;
    idagio.configLocation = config.sops.secrets.idagio.path;
    idagio.package = inputs.idagio.packages.x86_64-linux.default;
  };

  # NZBGet scripts require python
  nixpkgs.overlays = [
    (_final: prev: {
      nzbget = prev.nzbget.overrideAttrs (old: {
        buildInputs = old.buildInputs ++ [ pkgs.python311 ];
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
    # config.services.bazarr.user
    config.services.qbittorrent.user
    config.services.nzbget.user
  ];

  sops.secrets.nzbget = {
    sopsFile = secrets.torrenter;
    owner = config.services.nzbget.user;
    path = "/var/lib/nzbget/nzbget.conf";
  };

  sops.secrets.anime-playlist = {
    sopsFile = secrets.torrenter;
    mode = "0444";
  };

  sops.secrets.idagio = {
    sopsFile = secrets.torrenter;
    mode = "0444";
  };

  environment.systemPackages = [
    restore-torrenter
    get-anime-music

    (import ../shells/remux/remux.nix { inherit pkgs lib; })
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
    services.nzbget.path = [ pkgs.python311 ];
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
    # services.bazarr.after = [ "media-NAS.mount" ];
    services.prowlarr.after = [ "media-NAS.mount" ];

    timers."anime-music-hourly" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
        Unit = "anime-music-hourly.service";
      };
    };
    services."anime-music-hourly" = {
      script = ''
        ${get-anime-music}/bin/get-anime-music
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };

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
        [ "$(stat -f -c %T ${config.nas.backup.location})" != "smb2" ] && exit 1
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.sonarr.dataDir}/ ${config.nas.backup.location}/torrenter/sonarr
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.radarr.dataDir}/ ${config.nas.backup.location}/torrenter/radarr
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.lidarr.dataDir}/ ${config.nas.backup.location}/torrenter/lidarr
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.readarr.dataDir}/ ${config.nas.backup.location}/torrenter/readarr
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace /var/lib/prowlarr/ ${config.nas.backup.location}/torrenter/prowlarr
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.qbittorrent.dataDir}/ ${config.nas.backup.location}/torrenter/qbittorrent
      '';
      # ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace /var/lib/bazarr/ ${config.nas.backup.location}/torrenter/bazarr
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  system.stateVersion = "23.11";
}
