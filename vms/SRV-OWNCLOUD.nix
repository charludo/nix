{ config, secrets, ... }:
{
  vm = {
    id = 2218;
    name = "SRV-OWNCLOUD";

    hardware.cores = 2;
    hardware.memory = 4096;
    hardware.storage = "16G";

    networking.openPorts.tcp = [
      config.services.ocis.port
      80
      443
    ];
    networking.openPorts.udp = [
      config.services.ocis.port
      80
      443
    ];
  };

  nas.enable = false; # TEMP
  age.secrets.owncloud.rekeyFile = secrets.owncloud;

  services.ocis = {
    enable = true;
    url = "https://192.168.22.118";
    environmentFile = config.age.secrets.owncloud.path;
    environment = {
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts."_" = {
      addSSL = true;
      sslCertificate = "/etc/certificate.pem";
      sslCertificateKey = "/etc/privatekey.pem";
      locations."/".proxyPass = "https://localhost:${toString config.services.ocis.port}";
      locations."/".extraConfig = ''
        proxy_ssl_verify off;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };

  system.stateVersion = "23.11";
}
