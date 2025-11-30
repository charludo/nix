{ config, private-settings, ... }:
let
  inherit (private-settings) domains;
in
{
  vm = {
    id = 2209;
    name = "SRV-VIKUNJA";

    hardware.cores = 2;
    hardware.memory = 4096;
    hardware.storage = "16G";

    networking.openPorts.tcp = [ config.services.vikunja.port ];
  };

  services.vikunja = {
    enable = true;
    frontendScheme = "https";
    frontendHostname = "planning.${domains.home}";
    settings.service.enableregistration = false;
  };

  nas.enable = true;
  nas.backup.enable = true;
  rsync."vikunja" = {
    tasks = [
      {
        from = "/var/lib/vikunja";
        to = "${config.nas.backup.stateLocation}/vikunja";
      }
    ];
  };
}
