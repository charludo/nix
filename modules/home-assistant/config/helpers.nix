{ config, lib, ... }:
let
  e = config.hass.entities;

  # Every zigbee device that declares a "battery" diagnostic entity,
  # mapped to its `sensor.<slug>_battery` entity id. Picked up below as
  # the membership of the `sensor.zigbee_min_battery` group so we don't
  # have to maintain a parallel hardcoded list.
  zigbeeBatteryEntities = lib.pipe config.hass.devices.zigbee [
    (lib.filterAttrs (_: dev: lib.elem "battery" (dev.diagnostic or [ ])))
    (lib.mapAttrsToList (name: _: e.sensor.${lib.ha.mkSlug name}.battery))
  ];
in
{
  services.home-assistant.config = {
    sensor = [
      {
        platform = "statistics";
        name = "Cumulative Rain 24h";
        entity_id = e.sensor.wetterstation.precipitation;
        state_characteristic = "change";
        max_age.hours = 24;
      }
      {
        platform = "statistics";
        name = "Cumulative Rain 8h";
        entity_id = e.sensor.wetterstation.precipitation;
        state_characteristic = "change";
        max_age.hours = 8;
      }
      {
        platform = "derivative";
        name = "Rain Rate";
        source = e.sensor.wetterstation.precipitation;
        unit_time = "h";
        time_window = "00:05:00";
        round = 2;
      }
      {
        platform = "group";
        unique_id = "sensor.zigbee_min_battery";
        name = "Zigbee Min Battery";
        type = "min";
        ignore_non_numeric = true;
        device_class = "battery";
        entities = zigbeeBatteryEntities;
      }
    ];

    template = [
      {
        sensor = [
          {
            name = "Delayed Thermometer Gewächshaus Temperature";
            state = "{{ states('${e.sensor.thermometer_gewachshaus.temperature}') }}";
          }
          {
            name = "Tursensor Last Changed";
            state = "{{ relative_time(states['${e.binary_sensor.tursensor.opening}'].last_changed) }}";
          }
          {
            name = "Weather Wind Gust";
            state = "{{ states('${e.sensor.openweathermap_windboengeschwindigkeit}') | float(0) }}";
            unit_of_measurement = "km/h";
            state_class = "measurement";
          }
        ];
      }
      {
        trigger = [
          {
            platform = "homeassistant";
            event = "start";
          }
          {
            platform = "time_pattern";
            minutes = "/15";
          }
        ];
        action = [
          {
            action = "weather.get_forecasts";
            target.entity_id = e.weather.openweathermap;
            data.type = "daily";
            response_variable = "daily";
          }
          {
            action = "weather.get_forecasts";
            target.entity_id = e.weather.openweathermap;
            data.type = "hourly";
            response_variable = "hourly";
          }
        ];
        sensor = [
          {
            name = "OpenWeatherMap Forecast Daily";
            unique_id = "openweathermap_forecast_daily";
            state = "{{ now().isoformat() }}";
            attributes.forecast = "{{ daily['${e.weather.openweathermap}'].forecast }}";
          }
          {
            name = "OpenWeatherMap Forecast Hourly";
            unique_id = "openweathermap_forecast_hourly";
            state = "{{ now().isoformat() }}";
            attributes.forecast = "{{ hourly['${e.weather.openweathermap}'].forecast }}";
          }
        ];
      }
    ];
  };
}
