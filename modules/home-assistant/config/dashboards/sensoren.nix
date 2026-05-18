{
  pkgs,
  lib,
  config,
  ...
}:
let
  ha = lib.ha;
  e = config.hass.entities;
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
              name = "Gewächshaus vs Terrasse";
              entities = [
                {
                  entity = e.sensor.thermometer_gewachshaus.temperature;
                  show_state = true;
                  state_adaptive_color = true;
                }
                {
                  entity = e.sensor.thermometer_terrasse.temperature;
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
                name = "Gewächshaus";
                tempEntity = e.sensor.thermometer_gewachshaus.temperature;
                humEntity = e.sensor.thermometer_gewachshaus.humidity;
                lowerBound = "~0";
                upperBound = "~30";
              })
              (ha.mkTempHumGraph {
                name = "Terrasse";
                tempEntity = e.sensor.thermometer_terrasse.temperature;
                humEntity = e.sensor.thermometer_terrasse.humidity;
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
          (ha.mkGridSection [
            (ha.mkPlotlyGraph {
              title = "Gewächshaus vs Terrasse";
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
                  entity = e.sensor.thermometer_terrasse.temperature;
                  name = "Terrasse";
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
          (ha.mkGridSection [
            (ha.mkPlotlyGraph {
              title = "Gewächshaus";
              entities = ha.mkTempHumPlotlyEntities e.sensor.thermometer_gewachshaus.humidity e.sensor.thermometer_gewachshaus.temperature;
              yRange = [
                0
                100
              ];
              y2Range = [
                (-5)
                20
              ];
            })
          ])
          (ha.mkGridSection [
            (ha.mkPlotlyGraph {
              title = "Terrasse";
              entities = ha.mkTempHumPlotlyEntities e.sensor.thermometer_terrasse.humidity e.sensor.thermometer_terrasse.temperature;
              yRange = [
                0
                100
              ];
              y2Range = [
                (-5)
                20
              ];
            })
          ])
          (ha.mkGridSection [
            (ha.mkPlotlyGraph {
              title = "Badezimmer";
              entities = ha.mkTempHumPlotlyEntities e.sensor.thermometer_badezimmer.humidity e.sensor.thermometer_badezimmer.temperature;
              yRange = [
                0
                100
              ];
              y2Range = [
                18
                28
              ];
            })
          ])
          (ha.mkGridSection [
            (ha.mkPlotlyGraph {
              title = "Wohnzimmer";
              entities = ha.mkTempHumPlotlyEntities e.sensor.thermometer_wohnzimmer.humidity e.sensor.thermometer_wohnzimmer.temperature;
              yRange = [
                0
                100
              ];
              y2Range = [
                18
                28
              ];
            })
          ])
          (ha.mkGridSection [
            (ha.mkPlotlyGraph {
              title = "Schlafzimmer";
              entities = ha.mkTempHumPlotlyEntities e.sensor.thermometer_schlafzimmer.humidity e.sensor.thermometer_schlafzimmer.temperature;
              yRange = [
                0
                100
              ];
              y2Range = [
                18
                28
              ];
            })
          ])
          (ha.mkGridSection [
            (ha.mkPlotlyGraph {
              title = "Büro";
              entities = ha.mkTempHumPlotlyEntities e.sensor.thermometer_buro.humidity e.sensor.thermometer_buro.temperature;
              yRange = [
                0
                100
              ];
              y2Range = [
                18
                28
              ];
            })
          ])
          (ha.mkGridSection [
            (ha.mkPlotlyGraph {
              title = "Serverschrank";
              entities = ha.mkTempHumPlotlyEntities e.sensor.thermometer_serverschrank.humidity e.sensor.thermometer_serverschrank.temperature;
              yRange = [
                0
                100
              ];
              y2Range = [
                20
                40
              ];
            })
          ])
          (ha.mkGridSection [
            (ha.mkPlotlyGraph {
              title = "Filamentbox";
              entities = ha.mkTempHumPlotlyEntities e.sensor.thermometer_filamentbox.humidity e.sensor.thermometer_filamentbox.temperature;
              yRange = [
                0
                100
              ];
              y2Range = [
                20
                40
              ];
            })
          ])
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
