{ private-settings, ... }:
let
  inherit (private-settings) domains loginAccounts forwards;
in
{
  mailserver = {
    enable = true;
    fqdn = "mail.${domains.personal}";
    domains = [
      domains.personal
      domains.blog
    ];
    messageSizeLimit = 209715200;
    certificateScheme = "acme";
    fullTextSearch = {
      enable = true;
      autoIndex = true;
      indexAttachments = true;
      enforced = "body";
    };
    loginAccounts = loginAccounts;
    forwards = forwards;
    localDnsResolver = false;
  };
}
