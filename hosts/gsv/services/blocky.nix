{
  imports = [ ../../common/optional/blocky.nix ];

  networking.firewall = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 ];
  };
  services.blocky.settings.ports.dns = 53;
}
