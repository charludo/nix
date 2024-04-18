{ pkgs, ... }:
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
    hostName = "SRV-PDF";
    interfaces = {
      ens18.ipv4.addresses = [{
        address = "192.168.20.38";
        prefixLength = 27;
      }];
    };
    defaultGateway = "192.168.20.34";
    firewall = {
      allowedTCPPorts = [ 8080 ];
      allowedUDPPorts = [ 8080 ];
    };
  };

  services.qemuGuest.enable = true;

  environment.systemPackages = [ pkgs.stirling-pdf ];
  systemd.services.stirling-pdf = {
    description = "Stirling PDF Service";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.stirling-pdf}/bin/Stirling-PDF";
      Restart = "always";
      RestartSec = "20s";
    };
  };
  system.stateVersion = "23.11";
}
