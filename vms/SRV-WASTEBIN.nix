{
  config,
  private-settings,
  secrets,
  ...
}:
{
  vm = {
    id = 2204;
    name = "SRV-WASTEBIN";

    hardware.cores = 1;
    hardware.memory = 1024;
    hardware.storage = "4G";

    networking.openPorts.tcp = [ 8080 ];
    networking.openPorts.udp = [ 8080 ];
  };

  age.secrets.wastebin.rekeyFile = secrets.wastebin;

  services.wastebin = {
    enable = true;
    secretFile = config.age.secrets.wastebin.path;
    settings = {
      WASTEBIN_BASE_URL = private-settings.domains.wastebin;
      WASTEBIN_ADDRESS_PORT = "0.0.0.0:8080";
    };
  };

  system.stateVersion = "23.11";
}
