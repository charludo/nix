{ lib, ... }:
let
  mkId = id: "0x${lib.replaceStrings [":"] [""] id}";
  domains = devices: lib.unique (lib.filter (attr: attr != "id" && attr != "area") (lib.concatMap (deviceName: lib.attrNames (devices.${deviceName})) (lib.attrNames devices)));
  mkDeviceEntities = deviceType: device: if lib.hasAttr deviceType device then (lib.genAttrs device.${deviceType} (entity: "${deviceType}.${mkId device.id}_${entity}")) // { id = mkId device.id; } // { area = device.area; } else { };
  mkDomain = devices: domain: (lib.foldl' (acc: device: acc // { ${device} = (mkDeviceEntities domain devices.${device}); }) { } (lib.attrNames devices));
  mkEntities = devices: lib.genAttrs (domains devices) (domain: mkDomain devices domain);

  devices = {
    # Utility
    bewegungsmelder = {
      id = "00:12:4b:00:2a:64:f5:1f";
      binary_sensor = [ "motion" ];
      diagnostic = [ "battery" ];
      area = "Schlafzimmer";
    };

    # Power outlets
    steckdose_serverschrank = {
      id = "a4:c1:38:a7:09:97:ff:85";
      sensor = [ "current" "power" "summation_delivered" "voltage" ];
      switch = [ "child_lock" "switch" ];
      select = [ "backlight_mode" "power_on_state" ];
      area = "Büro";
    };
    steckdose_terrasse_1 = {
      id = "a4:c1:38:e4:68:4c:2e:f8";
      sensor = [ "current" "power" "summation_delivered" "voltage" ];
      switch = [ "child_lock" "switch" ];
      select = [ "backlight_mode" "power_on_state" ];
      area = "Terrasse";
    };
    steckdose_wasserpumpe = {
      id = "a4:c1:38:7a:85:ae:fb:a3";
      sensor = [ "current" "power" "summation_delivered" "voltage" ];
      switch = [ "child_lock" "switch" ];
      select = [ "backlight_mode" "power_on_state" ];
      area = "Terrasse";
    };

    # Thermometers (indoor)
    thermometer_badezimmer = {
      id = "00:12:4b:00:2a:5d:46:ac";
      sensor = [ "humidity" "temperature" ];
      diagnostic = [ "battery" ];
      area = "Badezimmer";
    };
    thermometer_buro = {
      id = "00:12:4b:00:2a:5c:b0:a1";
      sensor = [ "humidity" "temperature" ];
      diagnostic = [ "battery" ];
      area = "Büro";
    };
    thermometer_filamentbox = {
      id = "00:12:4b:00:2a:5d:1c:3e";
      sensor = [ "humidity" "temperature" ];
      diagnostic = [ "battery" ];
      area = "Büro";
    };
    thermometer_schlafzimmer = {
      id = "00:12:4b:00:2a:5c:b4:14";
      sensor = [ "humidity" "temperature" ];
      diagnostic = [ "battery" ];
      area = "Schlafzimmer";
    };
    thermometer_serverschrank = {
      id = "00:12:4b:00:2a:5d:0e:3e";
      sensor = [ "humidity" "temperature" ];
      diagnostic = [ "battery" ];
      area = "Büro";
    };
    thermometer_wohnzimmer = {
      id = "00:12:4b:00:2a:5d:23:0b";
      sensor = [ "humidity" "temperature" ];
      diagnostic = [ "battery" ];
      area = "Wohnzimmer";
    };
    # Thermometers (outdoor)
    thermometer_gewachshaus = {
      id = "00:15:8d:00:09:45:19:da";
      sensor = [ "humidity" "temperature" ];
      diagnostic = [ "battery" ];
      area = "Terrasse";
    };
    thermometer_terrasse = {
      id = "00:15:8d:00:09:45:18:3a";
      sensor = [ "humidity" "temperature" ];
      diagnostic = [ "battery" ];
      area = "Terrasse";
    };


    # Lights
    strahler = {
      id = "00:17:88:01:08:5b:76:98";
      light = [ "light" ];
      number = [ "start_up_color_temperature" "start_up_current_level" ];
      area = "Wohnzimmer";
    };
  };

  entities = mkEntities devices;
  inherit (entities) sensor binary_sensor light switch select diagnostic;
in
{
  imports = [ ./_common.nix ];

  vm = {
    id = 2402;
    name = "SRV-HOMEASSISTANT";

    hardware.cores = 4;
    hardware.memory = 8192;
    hardware.storage = "8G";

    networking.openPorts.tcp = [ 80 ];
  };


  system.stateVersion = "23.11";
}
