{ config, private-settings, ... }:
let
  inherit (private-settings) domains gsv;
in
{
  sops.secrets.coturn = { owner = "turnserver"; };
  services.coturn = {
    enable = true;
    realm = "turn.${domains.blog}";

    listening-ips = [ "0.0.0.0" ];
    listening-port = 3478;

    relay-ips = [ gsv.ip ];
    min-port = 49152;
    max-port = 65535;

    cert = "${config.security.acme.certs."turn.${domains.blog}".directory}/fullchain.pem";
    pkey = "${config.security.acme.certs."turn.${domains.blog}".directory}/key.pem";

    secure-stun = true;
    lt-cred-mech = true;
    use-auth-secret = true;
    static-auth-secret-file = config.sops.secrets.coturn.path;

    no-dtls = true;
    no-tls = true;
    extraConfig = ''
      no-multicast-peers
      total-quota=50
    '';
  };

  services.nginx.virtualHosts = {
    "turn.${domains.blog}" = {
      forceSSL = true;
      enableACME = true;
    };
  };

  networking.firewall.allowedTCPPorts = [ config.services.coturn.listening-port ];
  networking.firewall.allowedUDPPorts = [ config.services.coturn.listening-port ];

  networking.firewall.allowedUDPPortRanges = [{
    from = config.services.coturn.min-port;
    to = config.services.coturn.max-port;
  }];
}
