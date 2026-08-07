{ config, private-settings, ... }:
{
  staticHosting.enable = true;
  staticHosting.siteConfigs = [
    {
      name = "personal";
      url = "${private-settings.domains.personal}";
      pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAWk2bqcdRDcXqakCB8oeO+cHmRSFTgkyJ4rEDwDLRG5";
      enableSSL = true;
      aliases = [ "www.${private-settings.domains.personal}" ];
    }
    {
      name = "webdesign";
      url = "${private-settings.domains.webdesign}";
      pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJuGvnQAAoSrQllO2NPjNl7Esf2AlCpALSYJZ6n7jkvp";
      enableSSL = true;
      acmeHost = private-settings.domains.webdesign;
      aliases = [ "www.${private-settings.domains.webdesign}" ];
    }
  ];

  security.acme.certs."${private-settings.domains.webdesign}" = {
    group = config.services.nginx.group;
    dnsProvider = "hetzner";
    dnsResolver = null;
    # TODO: replace with agenix path!
    environmentFile = "/var/lib/webdesign/acme";
    extraDomainNames = [
      "www.${private-settings.domains.webdesign}"
    ];
  };
}
