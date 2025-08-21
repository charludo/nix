{ private-settings, ... }:
{
  vm = {
    id = 2202;
    name = "SRV-PDF";

    hardware.cores = 2;
    hardware.memory = 4096;
    hardware.storage = "16G";

    networking.openPorts.tcp = [ 80 ];
    networking.openPorts.udp = [ 80 ];
  };

  services.stirling-pdf = {
    enable = true;
    environment = {
      SERVER_PORT = 8080;
    };
  };
  services.nginx = {
    enable = true;
    virtualHosts."pdf.${private-settings.domains.ad}" = {
      extraConfig = ''
        client_max_body_size 512M;
      '';
      locations."/".proxyPass = "http://localhost:8080";
    };
  };

  system.stateVersion = "23.11";
}
