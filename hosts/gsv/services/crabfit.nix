{ config, inputs, ... }:
let
  inherit (inputs.private-settings) domains;
in
{
  services.crabfit = {
    enable = true;

    api.host = "crab.${domains.blog}";
    api.port = 2945;

    frontend.host = "schedule.${domains.blog}";
    frontend.port = 2946;
  };

  services.nginx = {
    virtualHosts = {
      "crab.${domains.blog}" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://localhost:${builtins.toString config.services.crabfit.api.port}/";
          extraConfig = ''
            proxy_set_header  X-Script-Name /;
            proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_pass_header Authorization;
          '';
        };
      };
      "schedule.${domains.blog}" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://localhost:${builtins.toString config.services.crabfit.frontend.port}/";
          extraConfig = ''
            proxy_set_header  X-Script-Name /;
            proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_pass_header Authorization;
          '';
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [
    config.services.crabfit.api.port
    config.services.crabfit.frontend.port
  ];
}
