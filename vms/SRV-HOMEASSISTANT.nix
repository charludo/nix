{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../modules/home-assistant
    ../home-assistant
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
  snow.tags = lib.mkForce [ "vm" ];

  nas.backup.enable = true;

  services.postgresqlBackup = {
    enable = true;
    databases = [ "hass" ];
    compression = "zstd";
  };

  rsync."homeassistant" = {
    tasks = [
      {
        from = config.services.home-assistant.configDir;
        to = "${config.nas.backup.stateLocation}/home-assistant/hass";
        chown = "hass:hass";
        extraFlags = "--no-links";
      }
      {
        from = "/var/lib/music-assistant";
        to = "${config.nas.backup.stateLocation}/home-assistant/music-assistant";
      }
      {
        from = config.services.postgresqlBackup.location;
        to = "${config.nas.backup.stateLocation}/home-assistant/postgresql";
      }
    ];
  };

  services.music-assistant = {
    enable = true;
    openFirewall = true;
  };

  environment.systemPackages = [ pkgs.usbutils ];
  # proxmox.qemuExtraConf.usb0 = "host=10c4:ea60,usb3=1";
}
