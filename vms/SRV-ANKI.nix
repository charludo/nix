{ config, secrets, ... }:
{
  vm = {
    id = 2219;
    name = "SRV-ANKI";

    hardware.cores = 1;
    hardware.memory = 1024;
    hardware.storage = "8G";
  };

  services.anki-sync-server = {
    enable = true;
    address = "0.0.0.0";
    port = 8080;
    openFirewall = true;
    users = [
      {
        username = "charlotte";
        passwordFile = config.age.secrets.anki-charlotte.path;
      }
      {
        username = "marie";
        passwordFile = config.age.secrets.anki-marie.path;
      }
    ];
  };
  age.secrets.anki-charlotte.rekeyFile = secrets.charlotte-anki;
  age.secrets.anki-marie.rekeyFile = secrets.marie-anki;

  nas.backup.enable = true;
  rsync."anki" = {
    tasks = [
      {
        from = "/var/lib/anki-sync-server";
        to = "${config.nas.backup.stateLocation}/anki-sync-server";
      }
    ];
  };
}
