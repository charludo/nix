{
  pkgs,
  lib,
  config,
  ...
}:
let
  ha = lib.ha;
  e = config.hass.entities;
  cfg = (pkgs.formats.yaml { }).generate "dashboard-umwelt-details.yaml" {
    views = [
      {
        type = "sections";
        max_columns = 3;
        icon = "mdi:weather-partly-rainy";
        header = ha.mkViewHeader "Wetter";
        sections = [
          (ha.mkGridSection [
            (ha.mkMushTitle "Vorhersage")
            {
              type = "weather-forecast";
              entity = e.weather.openweathermap;
              show_current = true;
              show_forecast = true;
              forecast_type = "hourly";
              secondary_info_attribute = "wind_speed";
            }
            {
              type = "glance";
              entities = [
                {
                  entity = e.sensor.openweathermap_gefuhlte_temperatur;
                  name = "Gefühlt";
                }
                {
                  entity = e.sensor.sun_next_dawn;
                  name = "Sonnenaufgang";
                }
                {
                  entity = e.sensor.sun_next_dusk;
                  name = "Sonnenuntergang";
                }
              ];
            }
            {
              type = "history-graph";
              entities = [ e.sun.sun ];
            }
          ])
          (ha.mkGridSection [
            (ha.mkMushTitle "Echtzeit (Lokal)")

            # Wetterstation (Terrasse) — full sensor graphs.
            {
              type = "sensor";
              entity = e.sensor.wetterstation.temperature;
              name = "Temperatur";
              graph = "line";
              detail = 2;
              column_span = 2;
            }
            (ha.mkHStack [
              {
                type = "sensor";
                entity = e.sensor.wetterstation.humidity;
                name = "Luftfeuchtigkeit";
                graph = "line";
                detail = 2;
              }
              {
                type = "sensor";
                entity = e.sensor.wetterstation.pressure;
                name = "Druck";
                graph = "line";
                detail = 2;
              }
            ])
            (ha.mkHStack [
              {
                type = "sensor";
                entity = e.sensor.wetterstation.wind_speed;
                name = "Wind";
                graph = "line";
                detail = 2;
                icon = "mdi:weather-windy";
              }
              {
                type = "sensor";
                entity = e.sensor.wetterstation.wind_gust_speed;
                name = "Böen";
                graph = "line";
                detail = 2;
                icon = "mdi:weather-dust";
              }
            ])
            (ha.mkHStack [
              {
                type = "sensor";
                entity = e.sensor.wetterstation.wind_direction;
                name = "Windrichtung";
                graph = "line";
                detail = 2;
                icon = "mdi:compass-outline";
              }
              {
                type = "sensor";
                entity = e.sensor.wetterstation.precipitation;
                name = "Niederschlag";
                graph = "line";
                detail = 2;
                icon = "mdi:weather-pouring";
              }
            ])
            (ha.mkHStack [
              {
                type = "sensor";
                entity = e.sensor.wetterstation.illuminance;
                name = "Beleuchtung";
                graph = "line";
                detail = 2;
                icon = "mdi:white-balance-sunny";
              }
              {
                type = "sensor";
                entity = e.sensor.wetterstation.uv_index;
                name = "UV-Index";
                graph = "line";
                detail = 2;
                icon = "mdi:sun-wireless";
              }
            ])

            {
              type = "glance";
              title = "Nordseite";
              columns = 3;
              show_name = false;
              show_icon = true;
              show_state = true;
              entities = [
                { entity = e.sensor.thermometer_nordseite.temperature; }
                { entity = e.sensor.thermometer_nordseite.humidity; }
                { entity = e.sensor.thermometer_nordseite.pressure; }
              ];
            }
            {
              type = "glance";
              title = "Gewächshaus";
              columns = 3;
              show_name = false;
              show_icon = true;
              show_state = true;
              entities = [
                { entity = e.sensor.thermometer_gewachshaus.temperature; }
                { entity = e.sensor.thermometer_gewachshaus.humidity; }
                { entity = e.sensor.thermometer_gewachshaus.pressure; }
              ];
            }
          ])
          (ha.mkGridSection [
            (ha.mkMushTitle "Echtzeit (OpenWeather)")
            {
              type = "sensor";
              entity = e.sensor.openweathermap_temperatur;
              name = "Temperatur";
              graph = "line";
              detail = 2;
              column_span = 2;
            }
            (ha.mkHStack [
              {
                type = "sensor";
                entity = e.sensor.openweathermap_windgeschwindigkeit;
                name = "Windgeschwindigkeit";
                graph = "line";
                detail = 2;
              }
              {
                type = "sensor";
                entity = e.sensor.openweathermap_bewolkung;
                name = "Wolkendecke";
                graph = "line";
                detail = 2;
                icon = "mdi:clouds";
              }
            ])
            (ha.mkHStack [
              {
                type = "sensor";
                entity = e.sensor.weather_wind_gust;
                name = "Böengeschwindigkeit";
                graph = "line";
                detail = 2;
                icon = "mdi:weather-dust";
              }
              {
                type = "sensor";
                entity = e.sensor.openweathermap_regenintensitat;
                name = "Regenmenge";
                graph = "line";
                detail = 2;
              }
            ])
            {
              type = "custom:weather-radar-card";
              data_source = "RainViewer-DarkSky";
              map_style = "Dark";
              zoom_level = 10;
              static_map = false;
              show_zoom = false;
              show_marker = true;
              show_playback = false;
              extra_labels = false;
            }
          ])
        ];
      }
    ];
  };
in
{
  systemd.tmpfiles.rules = [
    "L+ /var/lib/hass/dashboard-umwelt-details.yaml - - - - ${cfg}"
  ];

  services.home-assistant.config.lovelace.dashboards.dashboard-umwelt-details = {
    mode = "yaml";
    filename = "dashboard-umwelt-details.yaml";
    title = "Wetter";
    icon = "mdi:weather-partly-rainy";
    show_in_sidebar = true;
    require_admin = false;
  };
}
