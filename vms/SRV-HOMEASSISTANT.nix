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
    runOnGPUHost = true;

    hardware.cores = 4;
    hardware.memory = 16384;
    hardware.storage = "8G";

    hardware.usb = [
      { id = "1a86:55d4"; } # Sonoff Zigbee 3.0 USB Dongle Plus V2
      { id = "8087:0037"; } # Onboard Intel Bluetooth
    ];

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

  hardware.enableRedistributableFirmware = true;

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
}
