{ private-settings, ... }:
{
  vm = {
    id = 2217;
    name = "SRV-WEBHOST";

    hardware.cores = 2;
    hardware.memory = 2048;
    hardware.storage = "16G";

    networking.openPorts.tcp = [ 80 ];
  };

  staticHosting.enable = true;
  staticHosting.siteConfigs = [
    {
      name = "japan";
      url = "japan.${private-settings.domains.home}";
      pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKW1zap7sAZ3alqRR1E5xlX33R+nW8Psw+GNDSZbuNoB";
      enableSSL = false;
    }
  ];

  system.stateVersion = "23.11";
}
