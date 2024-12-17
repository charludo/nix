{ config, pkgs, lib, inputs, ... }:
let
  services = "(${lib.concatStringsSep " " (lib.mapAttrsToList (n: _: "\"openvpn-${n}.service\"") config.services.openvpn.servers)})";
  surfshark-stop = pkgs.writeShellApplication {
    name = "surfshark-stop";
    text = ''
      services=${services}
      for service in "''${services[@]}"; do
          systemctl stop "$service"
      done
    '';
  };
  surfshark-random = pkgs.writeShellApplication {
    name = "surfshark-random";
    runtimeInputs = [ surfshark-stop ];
    text = ''
      systemctl daemon-reload
      ${surfshark-stop}/bin/surfshark-stop
      services=${services}
      random_service=$(printf "%s\n" "''${services[@]}" | shuf -n1)
      systemctl start "$random_service"
    '';
  };
  restore-torrenter = pkgs.writeShellApplication {
    name = "restore-torrenter";
    runtimeInputs = [ pkgs.rsync ];
    text = ''
      ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.sonarr.user}:${config.services.sonarr.group} /media/Backup/torrenter/sonarr/ ${config.services.sonarr.dataDir}
      ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.radarr.user}:${config.services.radarr.group} /media/Backup/torrenter/radarr/ ${config.services.radarr.dataDir}
      ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.lidarr.user}:${config.services.lidarr.group} /media/Backup/torrenter/lidarr/ ${config.services.lidarr.dataDir}
      ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.readarr.user}:${config.services.readarr.group} /media/Backup/torrenter/readarr/ ${config.services.readarr.dataDir}
      ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.bazarr.user}:${config.services.bazarr.group} /media/Backup/torrenter/bazarr/ /var/lib/bazarr
      ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown prowlarr:prowlarr /media/Backup/torrenter/prowlarr/ /var/lib/prowlarr
      ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.qbittorrent.user}:${config.services.qbittorrent.group} /media/Backup/torrenter/qbittorrent/ ${config.services.qbittorrent.dataDir}
    '';
  };
  get-anime-music = pkgs.writeShellApplication {
    name = "get-anime-music";
    runtimeInputs = [ pkgs.yt-dlp pkgs.coreutils pkgs.ffmpeg ];
    text = ''
      url="$(cat ${config.sops.secrets.anime-playlist.path})"
      target="/media/NAS/Musik/Anime"

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
    ../hosts/common/optional/surfshark.nix
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

  networking.firewall = {
    interfaces.ens18.allowedTCPPorts = [ 6789 ]; # NZBGet web interface
    extraCommands = ''
      iptables -A INPUT -s localhost -j ACCEPT
      iptables -A OUTPUT -d localhost -j ACCEPT
      iptables -A INPUT -i lo -j ACCEPT
      iptables -A OUTPUT -o lo -j ACCEPT

      iptables -A INPUT -s 192.168.0.0/16 -j ACCEPT
      iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT

      iptables -A OUTPUT -p udp --dport 1194 -j ACCEPT
      iptables -A INPUT -p udp --sport 1194 -j ACCEPT
      iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
      iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

      iptables -A OUTPUT -o tun0 -j ACCEPT

      iptables -A OUTPUT -m owner --gid-owner ${builtins.toString config.users.groups."${config.services.nzbget.user}".gid} -d 192.168.0.0/16 ! -o tun0 -j ACCEPT
      iptables -A OUTPUT -m owner --gid-owner ${builtins.toString config.users.groups."${config.services.qbittorrent.user}".gid} -d 192.168.0.0/16 ! -o tun0 -j ACCEPT
      iptables -A OUTPUT -m owner --gid-owner ${builtins.toString config.users.groups."${config.services.nzbget.user}".gid} -d 127.0.0.1 ! -o tun0 -j ACCEPT
      iptables -A OUTPUT -m owner --gid-owner ${builtins.toString config.users.groups."${config.services.qbittorrent.user}".gid} -d 127.0.0.1 ! -o tun0 -j ACCEPT
      iptables -A OUTPUT -m owner --gid-owner ${builtins.toString config.users.groups."${config.services.nzbget.user}".gid} ! -o tun0 -j REJECT
      iptables -A OUTPUT -m owner --gid-owner ${builtins.toString config.users.groups."${config.services.qbittorrent.user}".gid} ! -o tun0 -j REJECT

      iptables -P INPUT DROP
      iptables -P FORWARD DROP
      iptables -P OUTPUT DROP
    '';
  };
  networking.interfaces.ens18.ipv4.routes = [{
    address = "192.168.0.0";
    prefixLength = 16;
    via = config.vm.networking.gateway;
  }];

  services = {
    sonarr.enable = true;
    sonarr.openFirewall = true;

    radarr.enable = true;
    radarr.openFirewall = true;

    lidarr.enable = true;
    lidarr.openFirewall = true;

    readarr.enable = true;
    readarr.openFirewall = true;

    bazarr.enable = true;
    bazarr.openFirewall = true;

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
    (final: prev: {
      nzbget = prev.nzbget.overrideAttrs (old: {
        buildInputs = old.buildInputs ++ [ pkgs.python311 ];
      });
    })
  ];

  enableNas = true;
  enableNasBackup = true;
  users.users = {
    "${config.services.sonarr.user}".extraGroups = [ "nas" ];
    "${config.services.radarr.user}".extraGroups = [ "nas" ];
    "${config.services.lidarr.user}".extraGroups = [ "nas" ];
    "${config.services.readarr.user}".extraGroups = [ "nas" ];
    "${config.services.bazarr.user}".extraGroups = [ "nas" ];
    "${config.services.qbittorrent.user}".extraGroups = [ "nas" ];
    "${config.services.nzbget.user}".extraGroups = [ "nas" ];
  };

  sops.secrets.nzbget = {
    sopsFile = ./secrets/torrenter-secrets.sops.yaml;
    owner = config.services.nzbget.user;
    path = "/var/lib/nzbget/nzbget.conf";
  };

  sops.secrets.anime-playlist = {
    sopsFile = ./secrets/torrenter-secrets.sops.yaml;
    mode = "0444";
  };

  sops.secrets.idagio = {
    sopsFile = ./secrets/torrenter-secrets.sops.yaml;
    mode = "0444";
  };

  environment.systemPackages = [
    restore-torrenter
    get-anime-music
    surfshark-random
    surfshark-stop
    (import ../shells/remux/remux.nix { inherit pkgs; })
    (import ../shells/remux/remux-all.nix { inherit pkgs; })
  ];

  systemd = {
    # Ensure qbittorrent/nzbget only start AFTER a VPN connection has been established, and the NAS is mounted for *arr
    services.nzbget.bindsTo = [ "sys-devices-virtual-net-tun0.device" "media-NAS.mount" ];
    services.nzbget.after = [ "sys-devices-virtual-net-tun0.device" "media-NAS.mount" ];
    services.nzbget.partOf = [ "sys-devices-virtual-net-tun0.device" "media-NAS.mount" ];
    services.nzbget.path = [ pkgs.python311 ];
    services.qbittorrent.bindsTo = [ "sys-devices-virtual-net-tun0.device" "media-NAS.mount" ];
    services.qbittorrent.after = [ "sys-devices-virtual-net-tun0.device" "media-NAS.mount" ];
    services.qbittorrent.partOf = [ "sys-devices-virtual-net-tun0.device" "media-NAS.mount" ];
    services.sonarr.after = [ "media-NAS.mount" ];
    services.radarr.after = [ "media-NAS.mount" ];
    services.lidarr.after = [ "media-NAS.mount" ];
    services.readarr.after = [ "media-NAS.mount" ];
    services.bazarr.after = [ "media-NAS.mount" ];
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

    timers."surfshark-hop-weekly" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Sun 03:00";
        Persistent = true;
        Unit = "surfshark-hop-weekly.service";
      };
    };
    services."surfshark-hop-weekly" = {
      script = ''
        systemctl reboot
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };

    timers."surfshark-ensure-minutely" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "minutely";
        Persistent = true;
        Unit = "surfshark-ensure.service";
      };
    };
    services."surfshark-ensure" = {
      script = ''
        if ${pkgs.iproute2}/bin/ip a show tun0 &> /dev/null;
        then
        exit 0
        else
        ${surfshark-random}/bin/surfshark-random
        fi
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
        [ "$(stat -f -c %T /media/Backup)" != "smb2" ] && exit 1
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.sonarr.dataDir}/ /media/Backup/torrenter/sonarr
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.radarr.dataDir}/ /media/Backup/torrenter/radarr
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.lidarr.dataDir}/ /media/Backup/torrenter/lidarr
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.readarr.dataDir}/ /media/Backup/torrenter/readarr
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace /var/lib/bazarr/ /media/Backup/torrenter/bazarr
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace /var/lib/prowlarr/ /media/Backup/torrenter/prowlarr
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.qbittorrent.dataDir}/ /media/Backup/torrenter/qbittorrent
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  system.stateVersion = "23.11";
}

