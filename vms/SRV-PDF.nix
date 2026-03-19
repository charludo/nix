{
  vm = {
    id = 2202;
    name = "SRV-PDF";

    hardware.cores = 2;
    hardware.memory = 1024;
    hardware.storage = "8G";

    networking.openPorts.tcp = [ 3000 ];
  };

  services.bentopdf = {
    enable = true;
    domain = "_";
    nginx.enable = true;
    nginx.virtualHost.listen = [
      {
        addr = "0.0.0.0";
        port = 3000;
      }
    ];
  };
}
