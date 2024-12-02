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
    id = 2403;
    name = "SRV-HOMEASSISTANT";

    hardware.cores = 4;
    hardware.memory = 8192;
    hardware.storage = "8G";

    networking.openPorts.tcp = [ 80 ];
  };


  system.stateVersion = "23.11";

  services.home-assistant.lovelaceConfig = {
    views = [{
      cards = [
        {
          type = "vertical-stack";
          cards = [
            { type = "custom:mushroom-title-card"; title = "Temperatur & Wetter"; }
            { type = "custom:mini-graph-card"; name = "Gewächshaus vs Terrasse"; entities = [{ entity = "sensor.thermometer_gewachshaus_temperature"; show_state = true; state_adaptive_color = true; } { entity = "sensor.thermometer_terrasse_temperature"; show_state = true; show_indicator = true; state_adaptive_color = true; }]; show = { legend = false; extrema = true; }; font_size = 80; hour24 = true; height = 180; group_by = "hour"; lower_bound = "~0"; upper_bound = "~30"; lower_bound_secondary = "~0"; upper_bound_secondary = "~25"; }
            { type = "horizontal-stack"; cards = [{ type = "custom:mini-graph-card"; name = "Gewächshaus"; entities = [{ entity = "sensor.thermometer_gewachshaus_temperature"; show_state = true; state_adaptive_color = true; } { entity = "sensor.thermometer_gewachshaus_humidity"; show_state = true; y_axis = "secondary"; state_adaptive_color = true; }]; show = { legend = false; }; font_size = 80; hour24 = true; height = 180; group_by = "hour"; lower_bound = "~0"; upper_bound = "~30"; lower_bound_secondary = 0; upper_bound_secondary = 100; } { type = "custom:mini-graph-card"; name = "Terrasse"; entities = [{ entity = "sensor.thermometer_terrasse_temperature"; show_state = true; state_adaptive_color = true; } { entity = "sensor.thermometer_terrasse_humidity"; show_state = true; y_axis = "secondary"; state_adaptive_color = true; }]; show = { legend = false; }; font_size = 80; hour24 = true; height = 180; group_by = "hour"; lower_bound = "~0"; upper_bound = "~30"; lower_bound_secondary = 0; upper_bound_secondary = 100; }]; }
            { type = "horizontal-stack"; cards = [{ graph = "none"; type = "sensor"; entity = "sensor.cumulative_rain_8h"; detail = 2; name = "Regen (letzte 8h)"; unit = "mm"; hours_to_show = 8; } { graph = "none"; type = "sensor"; entity = "sensor.cumulative_rain_24h"; detail = 2; name = "Regen (letzte 24h)"; unit = "mm"; hours_to_show = 24; }]; }
          ];
        }
        {
          type = "vertical-stack";
          cards = [
            {
              type = "custom:mushroom-title-card";
              title = "Automatisierungen";
            }
            {
              type = "entities";
              entities = [
                { entity = "automation.deaktiviere_pumpe_nach_regen"; }
                { entity = "automation.warnung_temperatur_gewachshaus"; }
                { entity = "automation.heat_greenhouse"; }
              ];
            }
            { type = "entities"; entities = [ "${switch.steckdose_wasserpumpe.switch}" "switch.steckdose_terrasse_1_switch" ]; }
          ];
        }
        { type = "vertical-stack"; cards = [{ type = "vertical-stack"; cards = [{ type = "custom:mushroom-title-card"; title = "Wasserpumpe"; } { type = "custom:mushroom-light-card"; entity = "${switch.steckdose_wasserpumpe.switch}"; icon = "mdi:toggle-switch-outline"; use_light_color = false; show_brightness_control = false; } { type = "history-graph"; entities = [{ entity = "${switch.steckdose_wasserpumpe.switch}"; name = " "; }]; hours_to_show = 24; } { type = "custom:mini-graph-card"; name = "Verbrauch"; entities = [{ entity = "sensor.steckdose_wasserpumpe_power"; show_state = true; state_adaptive_color = true; } { entity = "sensor.steckdose_wasserpumpe_current"; show_state = true; y_axis = "secondary"; state_adaptive_color = true; }]; show = { legend = false; }; font_size = 80; hour24 = true; height = 180; group_by = "hour"; lower_bound = "~0"; upper_bound = "~120"; lower_bound_secondary = 0; upper_bound_secondary = 1; }]; } { type = "vertical-stack"; cards = [{ type = "custom:mushroom-title-card"; title = "Gewächshaus Heizung"; } { type = "custom:mushroom-light-card"; entity = "switch.steckdose_terrasse_1_switch"; icon = "mdi:toggle-switch-outline"; use_light_color = false; show_brightness_control = false; } { type = "history-graph"; entities = [{ entity = "switch.steckdose_terrasse_1_switch"; name = " "; }]; hours_to_show = 24; } { type = "custom:mini-graph-card"; name = "Verbrauch"; entities = [{ entity = "sensor.steckdose_terrasse_1_power"; show_state = true; state_adaptive_color = true; } { entity = "sensor.steckdose_terrasse_1_current"; show_state = true; y_axis = "secondary"; state_adaptive_color = true; }]; show = { legend = false; }; font_size = 80; hour24 = true; height = 180; group_by = "hour"; lower_bound = "~0"; upper_bound = "~120"; lower_bound_secondary = 0; upper_bound_secondary = 1; }]; }]; }
      ];
      icon = "mdi:greenhouse";
    }];
  };

}
