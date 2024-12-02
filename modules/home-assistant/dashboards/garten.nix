{ pkgs, lib, ... }:
let
  ha = lib.ha;
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
            (ha.mkHStack [
              {
                type = "sensor";
                entity = "sensor.cumulative_rain_8h";
                name = "Regen (letzte 8h)";
                graph = "none";
                detail = 2;
                unit = "mm";
                hours_to_show = 8;
              }
              {
                type = "sensor";
                entity = "sensor.cumulative_rain_24h";
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
                { entity = "automation.deaktiviere_pumpe_nach_regen"; }
                { entity = "automation.warnung_temperatur_gewachshaus"; }
                { entity = "automation.heat_greenhouse"; }
                { entity = "automation.pflanzenlicht_an_aus"; }
              ];
            }
            {
              type = "entities";
              entities = [
                { entity = "switch.steckdose_wasserpumpe_switch"; }
                { entity = "switch.steckdose_gewachshaus_heizung_switch"; }
                { entity = "switch.steckdose_pflanzenlicht_switch"; }
              ];
            }
            {
              type = "custom:mushroom-number-card";
              entity = "input_number.stunden_sonnenlicht_setzlinge";
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
              switchEntity = "switch.steckdose_wasserpumpe_switch";
              powerEntity = "sensor.steckdose_wasserpumpe_power";
              currentEntity = "sensor.steckdose_wasserpumpe_current";
            })
            (ha.mkPowerStack {
              title = "Gewächshaus Heizung";
              switchEntity = "switch.steckdose_gewachshaus_heizung_switch";
              powerEntity = "sensor.steckdose_gewachshaus_heizung_power";
              currentEntity = "sensor.steckdose_gewachshaus_heizung_current";
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
