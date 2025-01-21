{ pkgs, lib, config, ... }:
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
in
{
  imports = [
    ./_common.nix
  ];

  vm = {
    id = 2102;
    name = "SRV-SUWAYOMI";

    hardware.cores = 4;
    hardware.memory = 8192;
    hardware.storage = "16G";

    networking.nameservers = [ "1.1.1.1" ];
  };

  surfshark.enable = true;

  networking.firewall = {
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

  services.suwayomi-server = {
    enable = true;
    openFirewall = true;

    dataDir = "/var/lib/suwayomi-server";

    settings.server.extensionRepos = [
      "https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json"
      "https://raw.githubusercontent.com/ThePBone/tachiyomi-extensions-revived/repo/index.min.json"
    ];
  };

  services.flaresolverr.enable = false; # https://github.com/NixOS/nixpkgs/issues/332776

  services.readarr = {
    enable = true;
    openFirewall = true;
  };

  systemd = {
    services.suwayomi-server.after = [ "media-NAS.mount" ];
    services.readarr.after = [ "media-NAS.mount" ];

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

    timers."suwayomi-backup-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "suwayomi-backup-daily.service";
      };
    };
    services."suwayomi-backup-daily" = {
      script = ''
        [ "$(stat -f -c %T ${config.nas.backup.location})" == "smb2" ] && ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.suwayomi-server.dataDir}/ ${config.nas.backup.location}/suwayomi
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };

    timers."suwayomi-sync" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
        Unit = "suwayomi-sync.service";
      };
    };
    services."suwayomi-sync" = {
      script = ''
        [ "$(stat -f -c %T ${config.nas.location})" == "smb2" ] && find ${config.services.suwayomi-server.dataDir}/.local/share/Tachidesk/downloads/mangas/*/ -maxdepth 0 -type d -exec ${pkgs.rsync}/bin/rsync -avz --stats --inplace {}/ ${config.nas.location}/Manga \;
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };

    timers."readarr-backup-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "readarr-backup-daily.service";
      };
    };
    services."readarr-backup-daily" = {
      script = ''
        [ "$(stat -f -c %T ${config.nas.backup.location})" != "smb2" ] && exit 1
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.readarr.dataDir}/ ${config.nas.backup.location}/torrenter/readarr2
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  environment.systemPackages =
    let
      suwayomi-init = pkgs.writeShellApplication {
        name = "suwayomi-init";
        text = ''
          [ "$(stat -f -c %T ${config.nas.backup.location})" != "smb2" ] && exit 1
          ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.nas.backup.location}/suwayomi/ ${config.services.suwayomi-server.dataDir}
        '';
      };
      readarr-init = pkgs.writeShellApplication {
        name = "readarr-init";
        text = ''
          [ "$(stat -f -c %T ${config.nas.backup.location})" == "smb2" ] && ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.nas.backup.location}/torrenter/readarr2/ ${config.services.readarr.dataDir}
        '';
      };
    in
    [ surfshark-random surfshark-stop suwayomi-init readarr-init ];

  nas.enable = true;
  nas.backup.enable = true;
  nas.extraUsers = [
    config.services.suwayomi-server.user
    config.services.readarr.user
  ];

  system.stateVersion = "23.11";
}
