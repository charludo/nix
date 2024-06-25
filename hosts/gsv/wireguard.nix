{ config, inputs, pkgs, ... }:
let
  inherit (inputs.private-settings) gsv home domains;
in
{
  networking.nat.enable = true;
  networking.nat.externalInterface = gsv.interface;
  networking.nat.internalInterfaces = [ "wg0" ];
  networking.firewall = {
    allowedUDPPorts = [ 51867 ];
  };

  sops.secrets.wg-server = { };
  networking.wireguard.interfaces = {
    wg0 = {
      ips = [ "192.168.42.2/30" ];
      listenPort = 51867;

      postSetup = ''
        ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 192.168.0.0/16 -o ${gsv.interface} -j MASQUERADE
      '';
      postShutdown = ''
        ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 192.168.0.0/16 -o ${gsv.interface} -j MASQUERADE
      '';

      privateKeyFile = config.sops.secrets.wg-server.path;

      peers = [
        {
          # endpoint = "${domains.vpn}:51867";
          publicKey = home.publicKey;
          allowedIPs = [ "192.168.0.0/16" ];
          persistentKeepalive = 25;
        }
      ];
    };
  };
}
