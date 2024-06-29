{ config, pkgs, inputs, ... }:
let
  inherit (inputs.private-settings) gsv;
in
{
  services.roundcube = {
    enable = true;
    hostName = "mail.${gsv.domain}";
    configureNginx = true;
    dicts = with pkgs.aspellDicts; [ de en ];
    extraConfig = ''
      $config['smtp_server'] = "tls://${config.mailserver.fqdn}";
      $config['smtp_user'] = "%u";
      $config['smtp_pass'] = "%p";
    '';
  };
}
