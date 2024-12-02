{
  pkgs,
  lib,
  config,
  ...
}:
let
  ha = lib.ha;
  e = config.hass.entities;

  st = e.sensor.wetterstation;

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
            (ha.mkGlanceCard {
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
            })
            (ha.mkHistoryGraph [ e.sun.sun ])
          ])

          (ha.mkGridSection [
            (ha.mkMushTitle "Messwerte")
            (ha.mkSensorCard {
              entity = st.temperature;
              name = "Temperatur";
              gridOptions = {
                columns = "full";
                rows = 3;
              };
              cardModStyle = "ha-card { height: 100% !important; }";
            })
            (ha.mkHStack [
              (ha.mkSensorCard {
                entity = e.sensor.rain_rate;
                name = "Niederschlag";
                icon = "mdi:weather-pouring";
                unit = "mm/h";
              })
              (ha.mkSensorCard {
                entity = e.sensor.openweathermap_bewolkung;
                name = "Wolkendecke (OWM)";
                icon = "mdi:clouds";
              })
            ])
            (ha.mkHStack [
              (ha.mkSensorCard {
                entity = st.humidity;
                name = "Luftfeuchtigkeit";
              })
              (ha.mkSensorCard {
                entity = st.pressure;
                name = "Luftdruck";
              })
              (ha.mkSensorCard {
                entity = st.illuminance;
                name = "Lichtintensität";
                icon = "mdi:white-balance-sunny";
              })
            ])
            (ha.mkUvGauge st.uv_index)
            (ha.mkGlanceCard {
              title = "Nordseite";
              columns = 3;
              showName = false;
              showIcon = true;
              showState = true;
              entities = [
                e.sensor.thermometer_nordseite.temperature
                e.sensor.thermometer_nordseite.humidity
                e.sensor.thermometer_nordseite.pressure
              ];
            })
            (ha.mkGlanceCard {
              title = "Gewächshaus";
              columns = 3;
              showName = false;
              showIcon = true;
              showState = true;
              entities = [
                e.sensor.thermometer_gewachshaus.temperature
                e.sensor.thermometer_gewachshaus.humidity
                e.sensor.thermometer_gewachshaus.pressure
              ];
            })
          ])

          (ha.mkGridSection [
            (ha.mkMushTitle "Wind")
            (ha.mkHStack [
              (ha.mkSensorCard {
                entity = st.wind_speed;
                name = "Windgeschwindigkeit";
              })
              (ha.mkSensorCard {
                entity = st.gust_speed;
                name = "Böengeschwindigkeit";
                icon = "mdi:weather-dust";
              })
            ])
            {
              type = "custom:windrose-card";
              title = "Windrichtung";
              card_mod.style."ha-card"."$" = ''
                .card-header {
                  font-size: var(--ha-font-size-l) !important;
                  color: var(--secondary-text-color) !important;
                }
              '';
              refresh_interval = 300;
              wind_direction_entity.entity = st.wind_direction;
              windspeed_entities = [
                {
                  entity = st.wind_speed;
                  name = "Wind";
                  use_for_windrose = true;
                  current_speed_arrow = true;
                  windspeed_bar_full = false;
                  bar_render_scale = "percentage_relative";
                }
                {
                  entity = st.gust_speed;
                  name = "Böen";
                  output_speed_unit = "mps";
                  speed_range_beaufort = false;
                  current_speed_arrow = true;
                  bar_render_scale = "windspeed_relative";
                }
              ];
              buttons_config = {
                location = "top";
                buttons = [
                  {
                    type = "period_selector";
                    button_text = "10min";
                    period_back = "-10mi";
                  }
                  {
                    type = "period_selector";
                    button_text = "1h";
                    period_back = "-1h";
                  }
                  {
                    type = "period_selector";
                    button_text = "8h";
                    period_back = "-8h";
                    active = true;
                  }
                  {
                    type = "period_selector";
                    button_text = "1d";
                    period_back = "-1d";
                  }
                ];
              };
              current_direction.show_arrow = true;
              direction_labels.cardinal_direction_letters = "NOSW";
              actions.windrose.tap_action = {
                action = "more-info";
                entity = st.wind_direction;
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
