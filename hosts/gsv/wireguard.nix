{ config, inputs, pkgs, ... }:
let
  inherit (inputs.private-settings) gsv home domains;
in
{
  environment.systemPackages = [ pkgs.dig ];
  networking.nat.enable = true;
  networking.nat.externalInterface = gsv.interface;
  networking.nat.internalInterfaces = [ "wg0" ];
  networking.firewall = {
    enable = true;
    allowedUDPPorts = [ 51867 ];
    checkReversePath = "loose";
    trustedInterfaces = [ "wg0" ];
  };

  sops.secrets.wg-server = { };
  # sops.secrets.wg-preshared = { };
  networking.wireguard.interfaces = {
    wg0 = {
      ips = [ "192.168.42.2/30" ];
      listenPort = 51867;
      # dns = [ "127.0.0.1" ];
      mtu = 1410;

      # postSetup = ''
      #   # ${pkgs.iptables}/bin/iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
      #   # ${pkgs.iptables}/bin/iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
      #   # ${pkgs.iptables}/bin/iptables -A FORWARD -i wg0 -o wg0 -m conntrack --ctstate NEW -j ACCEPT
      #   # ${pkgs.iptables}/bin/iptables -A FORWARD -i wg0 -j ACCEPT
      #   ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 0.0.0.0/0 -o ${gsv.interface} -j MASQUERADE
      #
      # '';
      # postShutdown = ''
      #   # ${pkgs.iptables}/bin/iptables -D INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
      #   # ${pkgs.iptables}/bin/iptables -D FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
      #   # ${pkgs.iptables}/bin/iptables -D FORWARD -i wg0 -o wg0 -m conntrack --ctstate NEW -j ACCEPT
      #   # ${pkgs.iptables}/bin/iptables -D FORWARD -i wg0 -j ACCEPT
      #   ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 0.0.0.0/0 -o ${gsv.interface} -j MASQUERADE
      # '';

      privateKeyFile = config.sops.secrets.wg-server.path;

      peers = [
        {
          # endpoint = "${domains.vpn}:51867";
          publicKey = home.publicKey;
          allowedIPs = [ "192.168.0.0/16" ];
          # persistentKeepalive = 25;
          # presharedKeyFile = config.sops.secrets.wg-preshared.path;
        }
      ];
    };
  };
}
