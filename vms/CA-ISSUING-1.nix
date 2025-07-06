{
  config,
  lib,
  private-settings,
  secrets,
  ...
}:
{
  vm = {
    id = 3033;
    name = "CA-ISSUING-1";

    hardware.cores = 1;
    hardware.memory = 1024;
    hardware.storage = "16G";

    networking.address = "192.168.30.33";
    networking.gateway = "192.168.30.1";
    networking.prefixLength = 24;

    certsFor = [
      {
        name = "ca-issuing-1";
        port = config.services.step-ca.port;
      }
    ];
  };

  age.secrets.ca-issuing-1.rekeyFile = secrets.ca-issuing-1;
  services.step-ca = {
    enable = true;
    intermediatePasswordFile = config.age.secrets.ca-issuing-1.path;
    settings = private-settings.caIssuing1;
    address = "0.0.0.0";
    port = 8443;
    openFirewall = true;
  };

  # Needed to bootstrap signing the actual server URL's certificate
  security.acme.defaults.server = "https://${config.vm.networking.address}:${builtins.toString config.services.step-ca.port}/acme/acme/directory";
  services.nginx.virtualHosts."${builtins.head private-settings.caIssuing1.dnsNames}".locations."/".proxyPass =
    lib.mkForce "https://127.0.0.1:${builtins.toString config.services.step-ca.port}";
  networking.hosts."127.0.0.1" = lib.mkForce [ ];
  networking.hosts."192.168.30.33" = lib.mkForce [ ];

  system.stateVersion = "23.11";
}
