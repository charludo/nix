{ pkgs, lib, ... }:
let
  ha = lib.ha;
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
                  entity = "sensor.thermometer_gewachshaus_temperature";
                  show_state = true;
                  state_adaptive_color = true;
                }
                {
                  entity = "sensor.thermometer_terrasse_temperature";
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
                tempEntity = "sensor.thermometer_gewachshaus_temperature";
                humEntity = "sensor.thermometer_gewachshaus_humidity";
                lowerBound = "~0";
                upperBound = "~30";
              })
              (ha.mkTempHumGraph {
                name = "Terrasse";
                tempEntity = "sensor.thermometer_terrasse_temperature";
                humEntity = "sensor.thermometer_terrasse_humidity";
                lowerBound = "~0";
                upperBound = "~30";
              })
            ])
          ])
          (ha.mkGridSection [
            (ha.mkMushTitle "Drinnen")
            (ha.mkTempHumGraph {
              name = "Wohnzimmer";
              tempEntity = "sensor.thermometer_wohnzimmer_temperature";
              humEntity = "sensor.thermometer_wohnzimmer_humidity";
            })
            (ha.mkHStack [
              (ha.mkTempHumGraph {
                name = "Schlafzimmer";
                tempEntity = "sensor.thermometer_schlafzimmer_temperature";
                humEntity = "sensor.thermometer_schlafzimmer_humidity";
              })
              (ha.mkTempHumGraph {
                name = "Büro";
                tempEntity = "sensor.thermometer_buro_temperature";
                humEntity = "sensor.thermometer_buro_humidity";
              })
            ])
            (ha.mkTempHumGraph {
              name = "Badezimmer";
              tempEntity = "sensor.thermometer_badezimmer_temperature";
              humEntity = "sensor.thermometer_badezimmer_humidity";
            })
          ])
          (ha.mkGridSection [
            (ha.mkMushTitle "Geräte")
            (ha.mkHStack [
              (ha.mkTempHumGraph {
                name = "Serverschrank";
                tempEntity = "sensor.thermometer_serverschrank_temperature";
                humEntity = "sensor.thermometer_serverschrank_humidity";
                upperBound = "~30";
              })
              (ha.mkTempHumGraph {
                name = "Filamentbox";
                tempEntity = "sensor.thermometer_filamentbox_temperature";
                humEntity = "sensor.thermometer_filamentbox_humidity";
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
                  entity = "sensor.thermometer_gewachshaus_temperature";
                  name = "Gewächshaus";
                  line = {
                    width = 2;
                    color = "orange";
                  };
                }
                {
                  entity = "sensor.thermometer_terrasse_temperature";
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
              entities = ha.mkTempHumPlotlyEntities "sensor.thermometer_gewachshaus_humidity" "sensor.thermometer_gewachshaus_temperature";
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
              entities = ha.mkTempHumPlotlyEntities "sensor.thermometer_terrasse_humidity" "sensor.thermometer_terrasse_temperature";
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
              entities = ha.mkTempHumPlotlyEntities "sensor.thermometer_badezimmer_humidity" "sensor.thermometer_badezimmer_temperature";
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
              entities = ha.mkTempHumPlotlyEntities "sensor.thermometer_wohnzimmer_humidity" "sensor.thermometer_wohnzimmer_temperature";
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
              entities = ha.mkTempHumPlotlyEntities "sensor.thermometer_schlafzimmer_humidity" "sensor.thermometer_schlafzimmer_temperature";
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
              entities = ha.mkTempHumPlotlyEntities "sensor.thermometer_buro_humidity" "sensor.thermometer_buro_temperature";
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
              entities = ha.mkTempHumPlotlyEntities "sensor.thermometer_serverschrank_humidity" "sensor.thermometer_serverschrank_temperature";
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
              entities = ha.mkTempHumPlotlyEntities "sensor.thermometer_filamentbox_humidity" "sensor.thermometer_filamentbox_temperature";
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
