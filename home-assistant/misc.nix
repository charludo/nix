{ config, lib, ... }:
let
  e = config.hass.entities;
in
{
  services.home-assistant.config = {
    sensor = [
      {
        platform = "group";
        unique_id = "sensor.zigbee_min_battery";
        name = "Zigbee Min Battery";
        type = "min";
        ignore_non_numeric = true;
        device_class = "battery";
        entities = lib.pipe config.hass.devices.zigbee [
          (lib.filterAttrs (_: dev: lib.elem "battery" (dev.diagnostic or [ ])))
          (lib.mapAttrsToList (name: _: e.sensor.${lib.ha.mkSlug name}.battery))
        ];
      }
    ];

    template = [
      {
        sensor = [
          {
            name = "Tursensor Last Changed";
            state = "{{ relative_time(states['${e.binary_sensor.tursensor.opening}'].last_changed) }}";
          }
        ];
      }
    ];
  };
}
