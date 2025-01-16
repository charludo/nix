{ inputs, ... }:
let
  inherit (inputs.private-settings) domains;
in
{
  services.nginx.virtualHosts = {
    "${domains.personal}" = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        root = ''${inputs.personal-site.packages."x86_64-linux".default}'';
      };
      extraConfig = ''
        error_page 404 /notfound;
      '';
    };
    "www.${domains.personal}" = {
      forceSSL = true;
      enableACME = true;
      globalRedirect = domains.personal;
    };

    "${domains.blog}" = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        root = ''${inputs.blog-site.packages."x86_64-linux".default}'';
      };
    };
    "www.${domains.blog}" = {
      forceSSL = true;
      enableACME = true;
      globalRedirect = domains.blog;
    };
  };
}

