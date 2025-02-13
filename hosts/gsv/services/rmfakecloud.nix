{
  config,
  private-settings,
  secrets,
  ...
}:
{
  services.rmfakecloud = {
    enable = true;
    storageUrl = "https://notes.${private-settings.domains.personal}";
    port = 3111;
    extraSettings.RM_HTTPS_COOKIE = "1";
    environmentFile = config.age.secrets.rmfakecloud.path;
  };

  services.nginx.virtualHosts."notes.${private-settings.domains.personal}" = {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString config.services.rmfakecloud.port}/";
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

  age.secrets.rmfakecloud.rekeyFile = secrets.rmfakecloud;
  networking.firewall.allowedTCPPorts = [ 443 ];

}
