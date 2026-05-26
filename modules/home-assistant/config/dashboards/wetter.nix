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
            (ha.mkMushTitle "Messwerte")
            {
              type = "sensor";
              entity = e.sensor.wetterstation.temperature;
              name = "Temperatur";
              graph = "line";
              detail = 2;
              grid_options = {
                columns = "full";
                rows = 3;
              };
              card_mod.style = "ha-card { height: 100% !important; }";
            }
            (ha.mkHStack [
              {
                type = "sensor";
                entity = e.sensor.wetterstation.precipitation;
                name = "Niederschlag";
                graph = "line";
                detail = 2;
                icon = "mdi:weather-pouring";
              }
              {
                type = "sensor";
                entity = e.sensor.openweathermap_bewolkung;
                name = "Wolkendecke (OWM)";
                graph = "line";
                detail = 2;
                icon = "mdi:clouds";
              }
            ])

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
                name = "Luftdruck";
                graph = "line";
                detail = 2;
              }
              {
                type = "sensor";
                entity = e.sensor.wetterstation.illuminance;
                name = "Beleuchtungsstärke";
                graph = "line";
                detail = 2;
                icon = "mdi:white-balance-sunny";
              }
            ])
            {
              type = "gauge";
              entity = e.sensor.wetterstation.uv_index;
              name = "UV-Index";
              min = 0;
              max = 13;
              needle = true;
              segments = [
                {
                  from = 0;
                  color = "#4eb84e";
                  label = "niedrig";
                }
                {
                  from = 2.5;
                  color = "#f6c700";
                  label = "mittel";
                }
                {
                  from = 5.5;
                  color = "#f08000";
                  label = "hoch";
                }
                {
                  from = 7.5;
                  color = "#d6001c";
                  label = "sehr hoch";
                }
                {
                  from = 10.5;
                  color = "#7a2bb5";
                  label = "extrem";
                }
              ];
            }
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
            (ha.mkMushTitle "Wind")
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
                entity = e.sensor.weather_wind_gust;
                name = "Böengeschwindigkeit";
                graph = "line";
                detail = 2;
                icon = "mdi:weather-dust";
              }
            ])
            {
              type = "custom:windrose-card";
              title = "Windrichtung";
              hide_windspeed_bar = true;
              refresh_interval = 300;
              data_period.period_back = "-24h";
              wind_direction_entity.entity = e.sensor.wetterstation.wind_direction;
              windspeed_entities = [
                {
                  entity = e.sensor.wetterstation.wind_speed;
                  name = "Wind";
                }
              ];
              current_direction.show_arrow = true;
              direction_labels.cardinal_direction_letters = "NOSW";
              actions.windrose = {
                tap_action = {
                  action = "more-info";
                  entity = e.sensor.wetterstation.wind_direction;
                };
              };
            }
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
