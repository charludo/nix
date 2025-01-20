{ pkgs, private-settings, ... }:
{
  imports = [ ./_common.nix ];

  vm = {
    id = 2202;
    name = "SRV-PDF";

    hardware.cores = 2;
    hardware.memory = 4096;
    hardware.storage = "4G";

    networking.openPorts.tcp = [ 80 ];
    networking.openPorts.udp = [ 80 ];
  };

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
