{ config, ... }:
{
  hass.areas = {
    "Terrasse" = {
      order = 1;
      icon = "mdi:sprout";
      temperatureEntity = config.hass.entities.sensor.thermometer_terrasse.temperature;
      humidityEntity = config.hass.entities.sensor.thermometer_terrasse.humidity;
    };
    "Wohnzimmer" = {
      order = 2;
      icon = "mdi:sofa";
      temperatureEntity = config.hass.entities.sensor.thermometer_wohnzimmer.temperature;
      humidityEntity = config.hass.entities.sensor.thermometer_wohnzimmer.humidity;
    };
    "Büro" = {
      order = 3;
      icon = "mdi:desktop-classic";
      temperatureEntity = config.hass.entities.sensor.thermometer_buro.temperature;
      humidityEntity = config.hass.entities.sensor.thermometer_buro.humidity;
    };
    "Schlafzimmer" = {
      order = 4;
      icon = "mdi:bed-king";
      temperatureEntity = config.hass.entities.sensor.thermometer_schlafzimmer.temperature;
      humidityEntity = config.hass.entities.sensor.thermometer_schlafzimmer.humidity;
    };
    "Badezimmer" = {
      order = 5;
      icon = "mdi:shower";
      temperatureEntity = config.hass.entities.sensor.thermometer_badezimmer.temperature;
      humidityEntity = config.hass.entities.sensor.thermometer_badezimmer.humidity;
    };
    "Flur" = {
      order = 6;
      icon = "mdi:door";
    };
  };
}
