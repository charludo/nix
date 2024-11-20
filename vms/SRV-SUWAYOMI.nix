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
    ../hosts/common/optional/surfshark.nix
  ];

  vm = {
    id = 2102;
    name = "SRV-SUWAYOMI";

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

  services.suwayomi-server = {
    enable = true;
    openFirewall = true;

    settings.server.extensionRepos = [
      "https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json"
    ];
  };

  systemd = {
    services.suwayomi-server.after = [ "media-NAS.mount" ];

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
  };

  environment.systemPackages = [ surfshark-random surfshark-stop ];

  enableNas = true;
  enableNasBackup = true;
  users.users."${config.services.suwayomi-server.user}".extraGroups = [ "nas" ];

  system.stateVersion = "23.11";
}
