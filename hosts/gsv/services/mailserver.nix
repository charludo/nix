{ config, private-settings, ... }:
let
  inherit (private-settings) domains loginAccounts forwards;
in
{
  mailserver = {
    enable = true;
    stateVersion = 3;
    fqdn = "mail.${domains.personal}";
    domains = [
      domains.personal
      domains.blog
    ];
    messageSizeLimit = 209715200;
    x509.useACMEHost = config.mailserver.fqdn;
    fullTextSearch = {
      enable = true;
      autoIndex = true;
      enforced = "body";
    };
    loginAccounts = loginAccounts;
    forwards = forwards;
    localDnsResolver = false;
  };
}
