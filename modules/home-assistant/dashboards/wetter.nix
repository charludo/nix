{ pkgs, lib, ... }:
let
  ha = lib.ha;
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
              entity = "weather.openweathermap";
              show_current = true;
              show_forecast = true;
              forecast_type = "hourly";
              secondary_info_attribute = "wind_speed";
            }
            {
              type = "glance";
              entities = [
                {
                  entity = "sensor.openweathermap_gefuhlte_temperatur";
                  name = "Gefühlt";
                }
                {
                  entity = "sensor.sun_next_dawn";
                  name = "Sonnenaufgang";
                }
                {
                  entity = "sensor.sun_next_dusk";
                  name = "Sonnenuntergang";
                }
              ];
            }
            {
              type = "history-graph";
              entities = [ "sun.sun" ];
            }
          ])
          (ha.mkGridSection [
            (ha.mkMushTitle "Echtzeit (Lokal)")
            {
              type = "glance";
              title = "Terrasse";
              columns = 3;
              show_name = false;
              show_icon = true;
              show_state = true;
              entities = [
                { entity = "sensor.thermometer_terrasse_temperature"; }
                { entity = "sensor.thermometer_terrasse_humidity"; }
                { entity = "sensor.thermometer_terrasse_pressure"; }
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
                { entity = "sensor.thermometer_gewachshaus_temperature"; }
                { entity = "sensor.thermometer_gewachshaus_humidity"; }
                { entity = "sensor.thermometer_gewachshaus_pressure"; }
              ];
            }
          ])
          (ha.mkGridSection [
            (ha.mkMushTitle "Echtzeit (OpenWeather)")
            {
              type = "sensor";
              entity = "sensor.openweathermap_temperatur";
              name = "Temperatur";
              graph = "line";
              detail = 2;
              column_span = 2;
            }
            (ha.mkHStack [
              {
                type = "sensor";
                entity = "sensor.openweathermap_windgeschwindigkeit";
                name = "Windgeschwindigkeit";
                graph = "line";
                detail = 2;
              }
              {
                type = "sensor";
                entity = "sensor.openweathermap_bewolkung";
                name = "Wolkendecke";
                graph = "line";
                detail = 2;
                icon = "mdi:clouds";
              }
            ])
            (ha.mkHStack [
              {
                type = "sensor";
                entity = "sensor.weather_wind_gust";
                name = "Böengeschwindigkeit";
                graph = "line";
                detail = 2;
                icon = "mdi:weather-dust";
              }
              {
                type = "sensor";
                entity = "sensor.openweathermap_regenintensitat";
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
