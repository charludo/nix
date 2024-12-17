{ inputs, ... }:
let
  inherit (inputs.private-settings) domains;
in
{
  services.static-web-server = {
    enable = true;
    root = ''${inputs.personal-site.packages."x86_64-linux".default}'';
    listen = "0.0.0.0:8787";
  };

  services.nginx.virtualHosts."${domains.personal}" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://localhost:8787/";
      extraConfig = ''
        proxy_set_header  X-Script-Name /;
        proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_pass_header Authorization;
      '';
    };
  };
}
