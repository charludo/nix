{ private-settings, secrets, ... }:
{
  networking.nat.enable = true;
  networking.nat.externalInterface = private-settings.gsv.interface;
  networking.nat.internalInterfaces = [ "wg0" ];
  networking.firewall.trustedInterfaces = [ "wg0" ];

  wireguard = {
    enable = true;
    autoStart = true;
    allowedIPs = "192.168.0.0/16";
    port = 51867;
    ip = "192.168.42.2/30";
    secrets = {
      secretsFilePrivate = secrets.gsv-wg-private;
      secretsFilePreshared = secrets.gsv-wg-preshared;
      remotePublicKey = private-settings.wireguard.publicKeys.gsv;
    };
  };
  # networking.interfaces.${private-settings.gsv.interface}.ipv4.routes = [
  #   {
  #     address = "192.168.0.0";
  #     prefixLength = 16;
  #     via = private-settings.gsv.gateway;
  #   }
  # ];
}
