{
  pkgs,
  lib,
  config,
  ...
}:
let
  ha = lib.ha;
  e = config.hass.entities;
  cfg = (pkgs.formats.yaml { }).generate "dashboard-garten.yaml" {
    views = [
      {
        type = "sections";
        max_columns = 3;
        icon = "mdi:greenhouse";
        header = ha.mkViewHeader "Garten";
        sections = [
          (ha.mkGridSection [
            (ha.mkMushTitle "Temperatur & Wetter")
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
            (ha.mkHStack [
              {
                type = "sensor";
                entity = e.sensor.cumulative_rain_8h;
                name = "Regen (letzte 8h)";
                graph = "none";
                detail = 2;
                unit = "mm";
                hours_to_show = 8;
              }
              {
                type = "sensor";
                entity = e.sensor.cumulative_rain_24h;
                name = "Regen (letzte 24h)";
                graph = "none";
                detail = 2;
                unit = "mm";
                hours_to_show = 24;
              }
            ])
          ])
          (ha.mkGridSection [
            (ha.mkMushTitle "Automatisierungen")
            {
              type = "entities";
              entities = [
                { entity = e.automation.deaktiviere_pumpe_nach_regen; }
                { entity = e.automation.warnung_temperatur_gewachshaus; }
                { entity = e.automation.heat_greenhouse; }
                { entity = e.automation.pflanzenlicht; }
              ];
            }
            {
              type = "entities";
              entities = [
                { entity = e.switch.steckdose_wasserpumpe.switch; }
                { entity = e.switch.steckdose_gewachshaus_heizung.switch; }
                { entity = e.switch.steckdose_pflanzenlicht.switch; }
              ];
            }
            {
              type = "custom:mushroom-number-card";
              entity = e.input_number.stunden_sonnenlicht_setzlinge;
              icon_color = "yellow";
              layout = "horizontal";
              fill_container = false;
              primary_info = "state";
              secondary_info = "name";
              display_mode = "slider";
              icon = "mdi:sprout";
            }
          ])
          (ha.mkGridSection [
            (ha.mkPowerStack {
              title = "Wasserpumpe";
              switchEntity = e.switch.steckdose_wasserpumpe.switch;
              powerEntity = e.sensor.steckdose_wasserpumpe.power;
              currentEntity = e.sensor.steckdose_wasserpumpe.current;
            })
            (ha.mkPowerStack {
              title = "Gewächshaus Heizung";
              switchEntity = e.switch.steckdose_gewachshaus_heizung.switch;
              powerEntity = e.sensor.steckdose_gewachshaus_heizung.power;
              currentEntity = e.sensor.steckdose_gewachshaus_heizung.current;
            })
          ])
        ];
      }
    ];
  };
in
{
  systemd.tmpfiles.rules = [
    "L+ /var/lib/hass/dashboard-garten.yaml - - - - ${cfg}"
  ];

  services.home-assistant.config.lovelace.dashboards.dashboard-garten = {
    mode = "yaml";
    filename = "dashboard-garten.yaml";
    title = "Garten";
    icon = "mdi:greenhouse";
    show_in_sidebar = true;
    require_admin = false;
  };
}
