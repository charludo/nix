{
  config,
  private-settings,
  secrets,
  ...
}:
let
  inherit (private-settings) domains gsv;
in
{
  age.secrets.turn = {
    rekeyFile = secrets.gsv-turn;
    owner = "turnserver";
  };
  services.coturn = {
    enable = true;
    realm = "turn.${domains.blog}";

    listening-ips = [ "0.0.0.0" ];
    listening-port = 3478;
    tls-listening-port = 3480;

    relay-ips = [ gsv.ip ];
    min-port = 49152;
    max-port = 65535;

    cert = "${config.security.acme.certs."turn.${domains.blog}".directory}/fullchain.pem";
    pkey = "${config.security.acme.certs."turn.${domains.blog}".directory}/key.pem";

    # no-auth = true;      # anonymous, is default when lt-cred-mech is false
    # secure-stun = true; # require auth for STUN
    lt-cred-mech = true;
    # use-auth-secret = true;
    static-auth-secret-file = config.age.secrets.turn.path;

    extraConfig = ''
      no-multicast-peers
      total-quota=50
    '';
  };

  # allow coturn to read certificate files
  users.users.turnserver.extraGroups = [ "nginx" ];

  services.nginx.virtualHosts = {
    "turn.${domains.blog}" = {
      forceSSL = true;
      enableACME = true;
    };
  };

  security.acme.certs = {
    "turn.${domains.blog}" = {
      postRun = "systemctl reload nginx.service; systemctl restart coturn.service";
    };
  };

  networking.firewall.allowedTCPPorts = [
    config.services.coturn.listening-port
    config.services.coturn.tls-listening-port
  ];
  networking.firewall.allowedUDPPorts = [
    config.services.coturn.listening-port
    config.services.coturn.tls-listening-port
  ];

  networking.firewall.allowedUDPPortRanges = [
    {
      from = config.services.coturn.min-port;
      to = config.services.coturn.max-port;
    }
  ];
}
