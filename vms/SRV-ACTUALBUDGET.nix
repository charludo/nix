{ config, ... }:
{
  vm = {
    id = 2214;
    name = "SRV-ACTUALBUDGET";

    hardware.cores = 2;
    hardware.memory = 4096;
    hardware.storage = "16G";

    certsFor = [
      {
        name = "actual";
        port = config.services.actual.settings.port;
      }
    ];
  };

  services.actual = {
    enable = true;
    settings.hostname = "127.0.0.1";
  };

  nas.backup.enable = true;
  rsync."actual" = {
    tasks = [
      {
        from = "${config.services.actual.settings.dataDir}";
        to = "${config.nas.backup.stateLocation}/actual";
        chown = "actual:actual";
      }
    ];
  };
}
