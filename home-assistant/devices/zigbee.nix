{ config, lib, ... }:
let
  a = lib.mapAttrs (_: v: v.name) config.hass.entities.area;

  mkThermometer = sensor: id: area: {
    inherit id area sensor;
    diagnostic = [ "battery" ];
  };
  thermometer = mkThermometer [
    "humidity"
    "temperature"
  ];
  thermometerPressure = mkThermometer [
    "humidity"
    "pressure"
    "temperature"
  ];

  steckdose = id: area: {
    inherit id area;
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
  };

  button = id: area: {
    inherit id area;
    diagnostic = [ "battery" ];
  };
in
{
  hass.devices.zigbee = {
    "Bewegungsmelder" = {
      id = "00:12:4b:00:2a:64:f5:1f";
      area = a.schlafzimmer;
      binary_sensor = [ "motion" ];
      diagnostic = [ "battery" ];
    };

    "Türsensor" = {
      id = "00:12:4b:00:2f:b4:9d:20";
      area = a.flur;
      binary_sensor = [ "opening" ];
      diagnostic = [ "battery" ];
    };

    "Strahler" = {
      id = "00:17:88:01:08:5b:76:98";
      area = a.wohnzimmer;
      light = [ "light" ];
      number = [
        "start_up_color_temperature"
        "start_up_current_level"
      ];
    };

    "Wetterstation" = {
      id = "08:b9:5f:ff:fe:d4:0f:1f";
      area = a.terrasse;
      binary_sensor = [ "moisture" ];
      sensor = [
        "gust_speed"
        "humidity"
        "illuminance"
        "pressure"
        "precipitation"
        "temperature"
        "uv_index"
        "wind_direction"
        "wind_speed"
      ];
      diagnostic = [ "battery" ];
    };

    "Thermometer Badezimmer" = thermometer "00:12:4b:00:2a:5d:46:ac" a.badezimmer;
    "Thermometer Büro" = thermometer "00:12:4b:00:2a:5c:b0:a1" a.buro;
    "Thermometer Filamentbox" = thermometer "00:12:4b:00:2a:5d:1c:3e" a.buro;
    "Thermometer Schlafzimmer" = thermometer "00:12:4b:00:2a:5c:b4:14" a.schlafzimmer;
    "Thermometer Serverschrank" = thermometer "00:12:4b:00:2a:5d:0e:3e" a.buro;
    "Thermometer Wohnzimmer" = thermometer "00:12:4b:00:2a:5d:23:0b" a.wohnzimmer;

    "Thermometer Gewächshaus" = thermometerPressure "00:15:8d:00:09:45:19:da" a.terrasse;
    "Thermometer Nordseite" = thermometerPressure "00:15:8d:00:09:45:18:3a" a.terrasse;

    "Steckdose Serverschrank" = steckdose "a4:c1:38:a7:09:97:ff:85" a.buro;
    "Steckdose Gewächshaus Heizung" = steckdose "a4:c1:38:e4:68:4c:2e:f8" a.terrasse; # DEAD!
    "Steckdose Wasserpumpe" = steckdose "a4:c1:38:5a:fc:f5:62:61" a.terrasse;
    "Steckdose Pflanzenlicht" = steckdose "a4:c1:38:7a:85:ae:fb:a3" a.wohnzimmer; # DEAD!

    "Button Sofa" = button "f0:44:d3:ff:fe:f9:8a:60" a.wohnzimmer;
    "Button Gewächshaus" = button "f0:44:d3:ff:fe:f9:86:c4" a.terrasse;
    "Button Büro" = button "f0:44:d3:ff:fe:f6:9e:0c" a.buro;
  };

  services.home-assistant.extraComponents = [
    "zha"
  ];

  services.home-assistant.config = {
    zha = {
      usb_path = "/dev/serial/by-id/usb-ITEAD_SONOFF_Zigbee_3.0_USB_Dongle_Plus_V2_20230807081647-if00";
      database_path = "zigbee.db";
    };
  };
}
