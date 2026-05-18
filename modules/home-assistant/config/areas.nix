{ config, ... }:
let
  thermo = name: {
    temperatureEntity = config.hass.entities.sensor.${name}.temperature;
    humidityEntity = config.hass.entities.sensor.${name}.humidity;
  };
in
{
  hass.areas = {
    "Terrasse" = thermo "thermometer_terrasse" // {
      order = 1;
      icon = "mdi:sprout";
    };
    "Wohnzimmer" = thermo "thermometer_wohnzimmer" // {
      order = 2;
      icon = "mdi:sofa";
    };
    "Büro" = thermo "thermometer_buro" // {
      order = 3;
      icon = "mdi:desktop-classic";
    };
    "Schlafzimmer" = thermo "thermometer_schlafzimmer" // {
      order = 4;
      icon = "mdi:bed-king";
    };
    "Badezimmer" = thermo "thermometer_badezimmer" // {
      order = 5;
      icon = "mdi:shower";
    };
    "Flur" = {
      order = 6;
      icon = "mdi:door";
    };
  };
}
