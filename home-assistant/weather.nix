{ config, ... }:
let
  e = config.hass.entities;
in
{
  hass.openweathermap.enable = true;

  services.home-assistant.extraComponents = [
    "sun"
    "met"
    "statistics"
  ];

  services.home-assistant.config = {
    sun = { };

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
    ];

    template = [
      {
        sensor = [
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
