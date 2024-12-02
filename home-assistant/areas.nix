{ config, ... }:
let
  thermometer = name: {
    temperatureEntity = config.hass.entities.sensor.${name}.temperature;
    humidityEntity = config.hass.entities.sensor.${name}.humidity;
  };
in
{
  hass.areas = {
    "Terrasse" = thermometer "wetterstation" // {
      order = 1;
      icon = "mdi:sprout";
    };
    "Wohnzimmer" = thermometer "thermometer_wohnzimmer" // {
      order = 2;
      icon = "mdi:sofa";
    };
    "Büro" = thermometer "thermometer_buro" // {
      order = 3;
      icon = "mdi:desktop-classic";
    };
    "Schlafzimmer" = thermometer "thermometer_schlafzimmer" // {
      order = 4;
      icon = "mdi:bed-king";
    };
    "Badezimmer" = thermometer "thermometer_badezimmer" // {
      order = 5;
      icon = "mdi:shower";
    };
    "Flur" = {
      order = 6;
      icon = "mdi:door";
    };
  };
}
