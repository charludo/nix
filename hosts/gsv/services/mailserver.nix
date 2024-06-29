{ inputs, ... }:
let
  inherit (inputs.private-settings) gsv loginAccounts;
in
{
  imports = [ inputs.mailserver.nixosModule ];

  mailserver = {
    enable = true;
    fqdn = "mail.${gsv.domain}";
    domains = [ gsv.domain ];
    messageSizeLimit = 209715200;
    certificateScheme = "acme";
    fullTextSearch = {
      enable = true;
      autoIndex = true;
      indexAttachments = true;
      enforced = "body";
    };
    loginAccounts = loginAccounts;
    localDnsResolver = false;
  };
}
