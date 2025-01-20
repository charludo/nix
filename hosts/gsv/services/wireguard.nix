{ config, private-settings, pkgs, ... }:
let
  inherit (private-settings) gsv home domains;
in
{
  environment.systemPackages = [ pkgs.dig ];
  networking.nat.enable = true;
  networking.nat.externalInterface = gsv.interface;
  networking.nat.internalInterfaces = [ "wg0" ];
  networking.firewall = {
    allowedUDPPorts = [ 51867 ];
    checkReversePath = "loose";
    trustedInterfaces = [ "wg0" ];
  };

  sops.secrets.wg-server = { };
  sops.secrets.wg-preshared = { };
  networking.wireguard.interfaces = {
    wg0 = {
      ips = [ "192.168.42.2/30" ];
      listenPort = 51867;
      mtu = 1420;

      privateKeyFile = config.sops.secrets.wg-server.path;

      peers = [
        {
          endpoint = "${domains.vpn}:51867";
          publicKey = home.publicKey;
          allowedIPs = [ "192.168.0.0/16" ];
          persistentKeepalive = 25;
          presharedKeyFile = config.sops.secrets.wg-preshared.path;
        }
      ];
    };
  };
}
