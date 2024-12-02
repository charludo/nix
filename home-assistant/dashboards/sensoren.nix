{
  pkgs,
  lib,
  config,
  ...
}:
let
  ha = lib.ha;
  e = config.hass.entities;

  # Standard temperature/humidity ranges for the detail plotly view.
  outdoorY2 = [
    (-5)
    20
  ];
  indoorY2 = [
    18
    28
  ];
  deviceY2 = [
    20
    40
  ];

  # Detail-view plot for one room/device: full y for humidity 0–100,
  # configurable temperature range.
  mkDetail =
    name: tempEntity: humEntity: y2Range:
    ha.mkGridSection [
      (ha.mkTempHumPlot {
        inherit
          name
          tempEntity
          humEntity
          y2Range
          ;
      })
    ];

  cfg = (pkgs.formats.yaml { }).generate "dashboard-umwelt.yaml" {
    views = [
      {
        type = "sections";
        max_columns = 3;
        icon = "mdi:sun-thermometer-outline";
        header = ha.mkViewHeader "Sensoren";
        sections = [
          (ha.mkGridSection [
            (ha.mkMushTitle "Draußen")
            (ha.mkMiniGraph {
              name = "Gewächshaus vs Wetterstation";
              entities = [
                {
                  entity = e.sensor.thermometer_gewachshaus.temperature;
                  show_state = true;
                  state_adaptive_color = true;
                }
                {
                  entity = e.sensor.wetterstation.temperature;
                  show_state = true;
                  show_indicator = true;
                  state_adaptive_color = true;
                }
              ];
              lower_bound = "~0";
              upper_bound = "~30";
              lower_bound_secondary = "~0";
              upper_bound_secondary = "~25";
              extraConfig.show = {
                legend = false;
                extrema = true;
              };
            })
            (ha.mkHStack [
              (ha.mkTempHumGraph {
                name = "Wetterstation";
                tempEntity = e.sensor.wetterstation.temperature;
                humEntity = e.sensor.wetterstation.humidity;
                lowerBound = "~0";
                upperBound = "~30";
              })
              (ha.mkTempHumGraph {
                name = "Gewächshaus";
                tempEntity = e.sensor.thermometer_gewachshaus.temperature;
                humEntity = e.sensor.thermometer_gewachshaus.humidity;
                lowerBound = "~0";
                upperBound = "~30";
              })
              (ha.mkTempHumGraph {
                name = "Nordseite";
                tempEntity = e.sensor.thermometer_nordseite.temperature;
                humEntity = e.sensor.thermometer_nordseite.humidity;
                lowerBound = "~0";
                upperBound = "~30";
              })
            ])
          ])
          (ha.mkGridSection [
            (ha.mkMushTitle "Drinnen")
            (ha.mkTempHumGraph {
              name = "Wohnzimmer";
              tempEntity = e.sensor.thermometer_wohnzimmer.temperature;
              humEntity = e.sensor.thermometer_wohnzimmer.humidity;
            })
            (ha.mkHStack [
              (ha.mkTempHumGraph {
                name = "Schlafzimmer";
                tempEntity = e.sensor.thermometer_schlafzimmer.temperature;
                humEntity = e.sensor.thermometer_schlafzimmer.humidity;
              })
              (ha.mkTempHumGraph {
                name = "Büro";
                tempEntity = e.sensor.thermometer_buro.temperature;
                humEntity = e.sensor.thermometer_buro.humidity;
              })
            ])
            (ha.mkTempHumGraph {
              name = "Badezimmer";
              tempEntity = e.sensor.thermometer_badezimmer.temperature;
              humEntity = e.sensor.thermometer_badezimmer.humidity;
            })
          ])
          (ha.mkGridSection [
            (ha.mkMushTitle "Geräte")
            (ha.mkHStack [
              (ha.mkTempHumGraph {
                name = "Serverschrank";
                tempEntity = e.sensor.thermometer_serverschrank.temperature;
                humEntity = e.sensor.thermometer_serverschrank.humidity;
                upperBound = "~30";
              })
              (ha.mkTempHumGraph {
                name = "Filamentbox";
                tempEntity = e.sensor.thermometer_filamentbox.temperature;
                humEntity = e.sensor.thermometer_filamentbox.humidity;
                upperBound = "~30";
              })
            ])
          ])
        ];
      }

      {
        type = "sections";
        max_columns = 3;
        path = "details";
        icon = "mdi:chart-scatter-plot-hexbin";
        header = ha.mkViewHeader "Sensordetails";
        sections = [
          # One-off comparison plot — two temperatures only, no humidity.
          (ha.mkGridSection [
            (ha.mkPlotlyGraph {
              title = "Gewächshaus vs Wetterstation";
              entities = [
                {
                  entity = e.sensor.thermometer_gewachshaus.temperature;
                  name = "Gewächshaus";
                  line = {
                    width = 2;
                    color = "orange";
                  };
                }
                {
                  entity = e.sensor.wetterstation.temperature;
                  name = "Wetterstation";
                  line = {
                    color = "orange";
                    width = 2;
                    dash = "dot";
                  };
                }
              ];
              yRange = [
                (-5)
                20
              ];
            })
          ])

          (mkDetail "Wetterstation" e.sensor.wetterstation.temperature e.sensor.wetterstation.humidity
            outdoorY2
          )
          (mkDetail "Gewächshaus" e.sensor.thermometer_gewachshaus.temperature
            e.sensor.thermometer_gewachshaus.humidity
            outdoorY2
          )
          (mkDetail "Nordseite" e.sensor.thermometer_nordseite.temperature
            e.sensor.thermometer_nordseite.humidity
            outdoorY2
          )
          (mkDetail "Badezimmer" e.sensor.thermometer_badezimmer.temperature
            e.sensor.thermometer_badezimmer.humidity
            indoorY2
          )
          (mkDetail "Wohnzimmer" e.sensor.thermometer_wohnzimmer.temperature
            e.sensor.thermometer_wohnzimmer.humidity
            indoorY2
          )
          (mkDetail "Schlafzimmer" e.sensor.thermometer_schlafzimmer.temperature
            e.sensor.thermometer_schlafzimmer.humidity
            indoorY2
          )
          (mkDetail "Büro" e.sensor.thermometer_buro.temperature e.sensor.thermometer_buro.humidity indoorY2)
          (mkDetail "Serverschrank" e.sensor.thermometer_serverschrank.temperature
            e.sensor.thermometer_serverschrank.humidity
            deviceY2
          )
          (mkDetail "Filamentbox" e.sensor.thermometer_filamentbox.temperature
            e.sensor.thermometer_filamentbox.humidity
            deviceY2
          )
        ];
      }
    ];
  };
in
{
  systemd.tmpfiles.rules = [
    "L+ /var/lib/hass/dashboard-umwelt.yaml - - - - ${cfg}"
  ];

  services.home-assistant.config.lovelace.dashboards.dashboard-umwelt = {
    mode = "yaml";
    filename = "dashboard-umwelt.yaml";
    title = "Sensoren";
    icon = "mdi:sun-thermometer-outline";
    show_in_sidebar = true;
    require_admin = false;
  };
}
