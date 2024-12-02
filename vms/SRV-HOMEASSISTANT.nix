{
  imports = [ ../modules/home-assistant ];

  vm = {
    id = 2403;
    name = "SRV-HOMEASSISTANT";

    hardware.cores = 4;
    hardware.memory = 8192;
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

  services.music-assistant = {
    enable = true;
    openFirewall = true;
    providers = [
      "jellyfin"
      "audiobookshelf"

      "sonos"
      "hass_players"
      "universal_group"

      "chromecast"
      "sendspin"
      "dlna"
    ];
  };

  hass.areas = {
    "Terrasse" = {
      order = 1;
      icon = "mdi:sprout";
      temperatureEntity = "sensor.thermometer_terrasse_temperature";
      humidityEntity = "sensor.thermometer_terrasse_humidity";
    };
    "Wohnzimmer" = {
      order = 2;
      icon = "mdi:sofa";
      temperatureEntity = "sensor.thermometer_wohnzimmer_temperature";
      humidityEntity = "sensor.thermometer_wohnzimmer_humidity";
    };
    "Büro" = {
      order = 3;
      icon = "mdi:desktop-classic";
      temperatureEntity = "sensor.thermometer_buro_temperature";
      humidityEntity = "sensor.thermometer_buro_humidity";
    };
    "Schlafzimmer" = {
      order = 4;
      icon = "mdi:bed-king";
      temperatureEntity = "sensor.thermometer_schlafzimmer_temperature";
      humidityEntity = "sensor.thermometer_schlafzimmer_humidity";
    };
    "Badezimmer" = {
      order = 5;
      icon = "mdi:shower";
      temperatureEntity = "sensor.thermometer_badezimmer_temperature";
      humidityEntity = "sensor.thermometer_badezimmer_humidity";
    };
    "Flur" = {
      order = 6;
      icon = "mdi:door";
    };
  };

  hass.devices = {
    "Bewegungsmelder" = {
      id = "00:12:4b:00:2a:64:f5:1f";
      binary_sensor = [ "motion" ];
      diagnostic = [ "battery" ];
      area = "Schlafzimmer";
    };

    "Steckdose Serverschrank" = {
      id = "a4:c1:38:a7:09:97:ff:85";
      sensor = [
        "current"
        "power"
        "summation_delivered"
        "voltage"
      ];
      switch = [
        "child_lock"
        "switch"
      ];
      select = [
        "backlight_mode"
        "power_on_state"
      ];
      area = "Büro";
    };

    "Steckdose Gewächshaus Heizung" = {
      id = "a4:c1:38:e4:68:4c:2e:f8";
      sensor = [
        "current"
        "power"
        "summation_delivered"
        "voltage"
      ];
      switch = [
        "child_lock"
        "switch"
      ];
      select = [
        "backlight_mode"
        "power_on_state"
      ];
      area = "Terrasse";
    };

    "Steckdose Wasserpumpe" = {
      id = "a4:c1:38:7a:85:ae:fb:a3";
      sensor = [
        "current"
        "power"
        "summation_delivered"
        "voltage"
      ];
      switch = [
        "child_lock"
        "switch"
      ];
      select = [
        "backlight_mode"
        "power_on_state"
      ];
      area = "Terrasse";
    };

    "Thermometer Badezimmer" = {
      id = "00:12:4b:00:2a:5d:46:ac";
      sensor = [
        "humidity"
        "temperature"
      ];
      diagnostic = [ "battery" ];
      area = "Badezimmer";
    };

    "Thermometer Büro" = {
      id = "00:12:4b:00:2a:5c:b0:a1";
      sensor = [
        "humidity"
        "temperature"
      ];
      diagnostic = [ "battery" ];
      area = "Büro";
    };

    "Thermometer Filamentbox" = {
      id = "00:12:4b:00:2a:5d:1c:3e";
      sensor = [
        "humidity"
        "temperature"
      ];
      diagnostic = [ "battery" ];
      area = "Büro";
    };

    "Thermometer Schlafzimmer" = {
      id = "00:12:4b:00:2a:5c:b4:14";
      sensor = [
        "humidity"
        "temperature"
      ];
      diagnostic = [ "battery" ];
      area = "Schlafzimmer";
    };

    "Thermometer Serverschrank" = {
      id = "00:12:4b:00:2a:5d:0e:3e";
      sensor = [
        "humidity"
        "temperature"
      ];
      diagnostic = [ "battery" ];
      area = "Büro";
    };

    "Thermometer Wohnzimmer" = {
      id = "00:12:4b:00:2a:5d:23:0b";
      sensor = [
        "humidity"
        "temperature"
      ];
      diagnostic = [ "battery" ];
      area = "Wohnzimmer";
    };

    "Thermometer Gewächshaus" = {
      id = "00:15:8d:00:09:45:19:da";
      sensor = [
        "humidity"
        "temperature"
      ];
      diagnostic = [ "battery" ];
      area = "Terrasse";
    };

    "Thermometer Terrasse" = {
      id = "00:15:8d:00:09:45:18:3a";
      sensor = [
        "humidity"
        "temperature"
      ];
      diagnostic = [ "battery" ];
      area = "Terrasse";
    };

    "Türsensor" = {
      id = "00:12:4b:00:2a:64:f5:20";
      binary_sensor = [ "opening" ];
      diagnostic = [ "battery" ];
      area = "Wohnzimmer";
    };

    "Steckdose Pflanzenlicht" = {
      id = "a4:c1:38:e4:68:4c:2e:01";
      sensor = [
        "current"
        "power"
        "summation_delivered"
        "voltage"
      ];
      switch = [
        "child_lock"
        "switch"
      ];
      select = [
        "backlight_mode"
        "power_on_state"
      ];
      area = "Terrasse";
    };

    "Strahler" = {
      id = "00:17:88:01:08:5b:76:98";
      light = [ "light" ];
      number = [
        "start_up_color_temperature"
        "start_up_current_level"
      ];
      area = "Wohnzimmer";
    };
  };
}
