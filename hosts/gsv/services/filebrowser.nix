{ config, private-settings, ... }:
{
  services.filebrowser = {
    enable = true;
    settings.port = 6317;
  };
  services.nginx.virtualHosts."share.${private-settings.domains.personal}" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.filebrowser.settings.port}/";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header  X-Script-Name /;
        proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_pass_header Authorization;
      '';
    };
    extraConfig = ''
      client_max_body_size 200M;
    '';
  };

}
