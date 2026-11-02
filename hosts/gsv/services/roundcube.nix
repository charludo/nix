{
  config,
  pkgs,
  private-settings,
  ...
}:
let
  inherit (private-settings) domains;
in
{
  services.roundcube = {
    enable = true;
    hostName = "mail.${domains.personal}";
    configureNginx = true;
    package = pkgs.roundcube.withPlugins (p: [
      p.contextmenu
      p.custom_from
    ]);
    plugins = [
      "attachment_reminder"
      "contextmenu"
      "custom_from"
    ];
    dicts = with pkgs.aspellDicts; [
      de
      en
    ];
    extraConfig = ''
      $config['imap_host'] = "ssl://${config.mailserver.fqdn}";
      $config['smtp_host'] = "ssl://${config.mailserver.fqdn}";
      $config['smtp_user'] = "%u";
      $config['smtp_pass'] = "%p";
    '';
  };
}
