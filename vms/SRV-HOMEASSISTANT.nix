{ pkgs }:
{
  imports = [
    ../modules/home-assistant
    ../modules/home-assistant/config
  ];

  vm = {
    id = 2403;
    name = "SRV-HOMEASSISTANT";

    hardware.cores = 4;
    hardware.memory = 16384;
    hardware.storage = "8G";

    networking.openPorts.tcp = [
      8123
      8927
      8095
      1400
    ];
    networking.openPorts.udp = [
      8123
      8927
      8095
      1400
    ];
  };

  # nas.backup.enable = true;
  #
  # services.postgresqlBackup = {
  #   enable = true;
  #   databases = [ "hass" ];
  #   compression = "zstd";
  # };
  #
  # rsync."srv-homeassistant" = {
  #   tasks = [
  #     {
  #       from = config.services.home-assistant.configDir;
  #       to = "${config.nas.backup.stateLocation}/hass";
  #       chown = "hass:hass";
  #       extraFlags = "--exclude=secrets.yaml";
  #     }
  #     {
  #       from = "/var/lib/music-assistant";
  #       to = "${config.nas.backup.stateLocation}/music-assistant";
  #     }
  #     {
  #       from = config.services.postgresqlBackup.location;
  #       to = "${config.nas.backup.stateLocation}/postgresql";
  #     }
  #   ];
  # };

  services.music-assistant = {
    enable = true;
    openFirewall = true;
  };

  environment.systemPackages = [ pkgs.lsusb ];
}
