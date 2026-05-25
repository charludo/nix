{ config, ... }:
let
  e = config.hass.entities;
in
{
  services.home-assistant.config = {
    sensor = [
      {
        platform = "statistics";
        name = "Cumulative Rain 24h";
        entity_id = e.sensor.wetterstation.precipitation;
        state_characteristic = "sum";
        max_age.hours = 24;
      }
      {
        platform = "statistics";
        name = "Cumulative Rain 8h";
        entity_id = e.sensor.wetterstation.precipitation;
        state_characteristic = "sum";
        max_age.hours = 8;
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
