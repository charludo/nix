{
  config,
  private-settings,
  secrets,
  ...
}:
let
  inherit (private-settings) domains;
in
{
  age.secrets.turn = {
    rekeyFile = secrets.gsv-turn;
    owner = "turnserver";
  };
  services.coturn = {
    enable = true;
    realm = "turn.${domains.blog}";

    listening-port = 3478;
    tls-listening-port = 3480;
    no-cli = true;

    min-port = 49152;
    max-port = 65535;

    cert = "${config.security.acme.certs."turn.${domains.blog}".directory}/full.pem";
    pkey = "${config.security.acme.certs."turn.${domains.blog}".directory}/key.pem";

    use-auth-secret = true;
    static-auth-secret-file = config.age.secrets.turn.path;

    extraConfig = ''
      verbose
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
