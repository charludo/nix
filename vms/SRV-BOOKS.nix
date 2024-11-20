{ config, lib, pkgs, ... }:
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
    ../hosts/common/optional/surfshark.nix
  ];

  vm = {
    id = 2208;
    name = "SRV-BOOKS";

    hardware.cores = 4;
    hardware.memory = 8192;
    hardware.storage = "16G";

    networking.nameservers = [ "1.1.1.1" ];
  };

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

  services.calibre-server = {
    enable = true;
    openFirewall = true;
    libraries = [ "/var/lib/calibre-server" ];
    auth = {
      enable = true;
      userDb = "${builtins.head config.services.calibre-server.libraries}/calibre.sqlite";
    };
  };

  services.readarr = {
    enable = true;
    openFirewall = true;
    user = config.services.calibre-server.user;
    group = config.services.calibre-server.group;
  };

  enableNas = true;
  enableNasBackup = true;
  users.users."${config.services.calibre-server.user}".extraGroups = [ "nas" ];

  systemd = {
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


    timers."calibre-backup-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "calibre-backup-daily.service";
      };
    };
    services."calibre-backup-daily" = {
      script = ''
        [ "$(stat -f -c %T /media/NAS)" != "smb2" ] && exit 1
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace --chown=${config.services.calibre-server.user}:${config.services.calibre-server.group} ${builtins.head config.services.calibre-server.libraries}/ /media/Backup/calibre
        ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace ${config.services.readarr.dataDir}/ /media/Backup/torrenter/readarr2
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  environment.systemPackages =
    let
      calibre-init = pkgs.writeShellApplication {
        name = "calibre-init";
        runtimeInputs = [ pkgs.rsync ];
        text = ''
          ${pkgs.rsync}/bin/rsync -avz --stats --delete --inplace --chown=${config.services.calibre-server.user}:${config.services.calibre-server.group} /media/Backup/calibre/ ${builtins.head config.services.calibre-server.libraries}
          ${pkgs.rsync}/bin/rsync -avzI --stats --delete --inplace --chown ${config.services.readarr.user}:${config.services.readarr.group} /media/Backup/torrenter/readarr2/ ${config.services.readarr.dataDir}
        '';
      };
    in
    [ calibre-init surfshark-random surfshark-stop pkgs.rsync ];

  system.stateVersion = "23.11";
}
