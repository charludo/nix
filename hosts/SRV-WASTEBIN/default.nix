{ inputs, config, ... }:
{
  _module.args.defaultUser = "paki";
  imports =
    [
      ./hardware-configuration.nix
      ../common/optional/vmify.nix

      ../common/global
      ../common/optional/nvim.nix

      ../../users/paki/user.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "SRV-WASTEBIN";
    interfaces = {
      ens18.ipv4.addresses = [{
        address = "192.168.20.39";
        prefixLength = 27;
      }];
    };
    defaultGateway = "192.168.20.34";
    nameservers = [ "1.1.1.1" ];
    firewall = {
      allowedTCPPorts = [ 8080 ];
    };
  };

  services.qemuGuest.enable = true;

  sops.secrets.wastebin = { sopsFile = ./wastebin-secrets.sops.yaml; };
  services.wastebin = {
    enable = true;
    secretFile = config.sops.secrets.wastebin.path;
    settings = {
      WASTEBIN_BASE_URL = inputs.private-settings.domains.wastebin;
      WASTEBIN_ADDRESS_PORT = "0.0.0.0:8080";
    };
  };

  system.stateVersion = "23.11";
}
