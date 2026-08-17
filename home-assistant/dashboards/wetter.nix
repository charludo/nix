{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib) ha;
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
            (ha.mkMainSideRow {
              main = ha.mkSensorCard {
                entity = e.sensor.rain_rate;
                name = "Niederschlag (2h)";
                icon = "mdi:weather-pouring";
                unit = "mm/h";
                hours_to_show = 2;
              };
              side = [
                (ha.mkSensorCard {
                  entity = e.sensor.cumulative_rain_8h;
                  name = "Gesamt (8h)";
                  icon = "mdi:sigma";
                  unit = "mm";
                  hours_to_show = 8;
                  graph = "none";
                })
                (ha.mkSensorCard {
                  entity = e.sensor.cumulative_rain_24h;
                  name = "Gesamt (24h)";
                  icon = "mdi:sigma";
                  unit = "mm";
                  hours_to_show = 24;
                  graph = "none";
                })
              ];
            })
            (ha.mkHStack [
              (ha.mkSensorCard {
                entity = e.sensor.openweathermap_bewolkung;
                name = "Wolkendecke (OWM)";
                icon = "mdi:clouds";
              })
              (ha.mkSensorCard {
                entity = st.illuminance;
                name = "Lichtintensität";
                icon = "mdi:white-balance-sunny";
              })
            ])
            (ha.mkUvGauge st.uv_index)
            (ha.mkHStack [
              (ha.mkSensorCard {
                entity = st.humidity;
                name = "Luftfeuchtigkeit";
              })
              (ha.mkSensorCard {
                entity = st.pressure;
                name = "Luftdruck";
              })
            ])
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
              data_source = "DWD";
              map_style = "Satellite";
              zoom_level = 11;
              static_map = false;

              past_minutes = 60;
              forecast_minutes = 60;
              frame_stride_minutes = 5;

              show_playback = true;
              show_progress_bar = true;
              show_color_bar = true;
              show_zoom = false;
              show_recenter = true;
              show_scale = true;
              extra_labels = false;

              start_paused = true;
              animated_transitions = true;
              smooth_animation = true;
              smooth_overlap = 0;
              motion_compensation = true;

              show_lightning = true;
              lightning_pulse = true;
              lightning_max_age_minutes = 30;

              dwd_wind = "arrows";
              dwd_wind_density = 0.5;
              dwd_wind_flow = true;
              dwd_wind_flow_color_sat = "rgba(255,255,255,0.5)";
              dwd_wind_flow_color_dark = "rgba(220,225,235,0.25)";

              markers = [
                {
                  entity = "zone.home";
                  icon = "mdi:home";
                }
              ];
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
