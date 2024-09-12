{ config, inputs, ... }:
let
  inherit (inputs.private-settings) domains;
in
{
  services.matrix-conduit = {
    enable = true;
    settings.global = {
      # allow_registration = true;
      server_name = "matrix.${domains.blog}";
      allow_federation = false;
      address = "127.0.0.1";
      database_backend = "rocksdb";
      turn_uris = [
        "turn:turn.${domains.blog}:${builtins.toString config.services.coturn.listening-port}?transport=udp"
        "turn:turn.${domains.blog}:${builtins.toString config.services.coturn.listening-port}?transport=tcp"
      ];
      turn_secret = "";
      enable_lightning_bolt = false;
    };
  };

  services.nginx.virtualHosts."matrix.${domains.blog}" = {
    enableACME = true;
    addSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString config.services.matrix-conduit.settings.global.port}/";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_buffering off;
        proxy_read_timeout 5m;
      '';
    };
    extraConfig = ''
      client_max_body_size 20M;
    '';
  };

  networking.firewall.allowedTCPPorts = [ 443 8448 ];
}

