{
  pkgs,
  lib,
  config,
  ...
}:
let
  ha = lib.ha;
  e = config.hass.entities;
  cfg = (pkgs.formats.yaml { }).generate "dashboard-stromverbrauch.yaml" {
    views = [
      {
        type = "sections";
        max_columns = 3;
        icon = "mdi:lightning-bolt";
        header = ha.mkViewHeader "Stromverbrauch";
        sections = [
          (ha.mkGridSection [
            (ha.mkPowerStack {
              title = "Terrasse 1";
              switchEntity = e.switch.steckdose_gewachshaus_heizung.switch;
              powerEntity = e.sensor.steckdose_gewachshaus_heizung.power;
              currentEntity = e.sensor.steckdose_gewachshaus_heizung.current;
            })
          ])
          (ha.mkGridSection [
            (ha.mkPowerStack {
              title = "Wasserpumpe";
              switchEntity = e.switch.steckdose_wasserpumpe.switch;
              powerEntity = e.sensor.steckdose_wasserpumpe.power;
              currentEntity = e.sensor.steckdose_wasserpumpe.current;
            })
          ])
          (ha.mkGridSection [
            (ha.mkPowerStack {
              title = "Serverschrank";
              switchEntity = e.switch.steckdose_serverschrank.switch;
              historyEntity = e.select.steckdose_serverschrank.power_on_state;
              historyExtra = {
                fit_y_data = false;
                logarithmic_scale = false;
              };
              powerEntity = e.sensor.steckdose_serverschrank.power;
              currentEntity = e.sensor.steckdose_serverschrank.current;
              upperCurrent = 10;
              extraCards = [
                {
                  type = "entities";
                  title = "Steckdose Serverschrank";
                  entities = [
                    {
                      entity = e.sensor.steckdose_serverschrank.current;
                      name = "Current";
                    }
                    {
                      entity = e.sensor.steckdose_serverschrank.power;
                      name = "Power";
                    }
                    {
                      entity = e.sensor.steckdose_serverschrank.summation_delivered;
                      name = "Summation delivered";
                    }
                    {
                      entity = e.sensor.steckdose_serverschrank.voltage;
                      name = "Voltage";
                    }
                  ];
                }
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
    "L+ /var/lib/hass/dashboard-stromverbrauch.yaml - - - - ${cfg}"
  ];

  services.home-assistant.config.lovelace.dashboards.dashboard-stromverbrauch = {
    mode = "yaml";
    filename = "dashboard-stromverbrauch.yaml";
    title = "Stromverbrauch";
    icon = "mdi:lightning-bolt";
    show_in_sidebar = true;
    require_admin = false;
  };
}
