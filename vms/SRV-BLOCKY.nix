{ config, private-settings, ... }:
let
  dohName = "dns";
  dohHost = "${dohName}.${private-settings.domains.ad}";
  dohPort = 4000;
  acmeDir = config.security.acme.certs.${dohHost}.directory;
in
{
  vm = {
    id = 3002;
    name = "SRV-BLOCKY";

    hardware.cores = 2;
    hardware.memory = 4096;
    hardware.storage = "16G";

    networking.address = "192.168.30.13";
    networking.gateway = "192.168.30.1";
    networking.prefixLength = 24;
    networking.nameservers = [ ];

    networking.openPorts.tcp = [
      53
      853
    ];
    networking.openPorts.udp = [
      53
      853
    ];

    # DNS-over-HTTPS: nginx terminates TLS, blocky answers /dns-query on plain HTTP
    certsFor = [
      {
        name = dohName;
        port = dohPort;
      }
    ];
  };

  # don't expose blocky's control API (e.g. disabling blocking) through the DoH vhost
  services.nginx.virtualHosts.${dohHost}.locations."/api/".return = "403";

  # DNS-over-TLS: blocky terminates TLS itself, reusing the ACME cert
  security.acme.certs.${dohHost}.reloadServices = [ "blocky.service" ];
  systemd.services.blocky.serviceConfig.LoadCredential = [
    "cert.pem:${acmeDir}/fullchain.pem"
    "key.pem:${acmeDir}/key.pem"
  ];
  systemd.services.blocky = {
    wants = [ "acme-finished-${dohHost}.target" ];
    after = [ "acme-finished-${dohHost}.target" ];
  };

  blocky.enable = true;
  blocky.addEntriesForVMs = true;
  services.blocky = {
    settings = {
      ports.dns = 53;
      ports.tls = 853;
      ports.http = "127.0.0.1:${toString dohPort}";
      certFile = "/run/credentials/blocky.service/cert.pem";
      keyFile = "/run/credentials/blocky.service/key.pem";
      caching = {
        minTime = "5m";
        maxTime = "30m";
        prefetching = true;
      };
    };
  };
}
