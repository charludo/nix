{ config, secrets, ... }:
{
  vm = {
    id = 2219;
    name = "SRV-ANKI";

    hardware.cores = 2;
    hardware.memory = 4096;
    hardware.storage = "16G";
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
