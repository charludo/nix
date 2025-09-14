{ private-settings, ... }:
{
  staticHosting.enable = true;
  staticHosting.siteConfigs = [
    {
      name = "personal";
      url = "${private-settings.domains.personal}";
      pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAWk2bqcdRDcXqakCB8oeO+cHmRSFTgkyJ4rEDwDLRG5";
      enableSSL = true;
    }
  ];
}
