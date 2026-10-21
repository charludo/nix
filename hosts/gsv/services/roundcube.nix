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
    enable = false;
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

  # Mitigation for the 2026-10 PHP RCE that works against the default config.
  # TODO: remove once php84 in nixpkgs is patched.
  # services.phpfpm.pools.roundcube.phpOptions = ''
  # session.upload_progress.enabled = Off
  # '';
}
