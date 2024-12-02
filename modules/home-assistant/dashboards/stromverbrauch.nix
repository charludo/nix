{ pkgs, lib, ... }:
let
  ha = lib.ha;
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
              switchEntity = "switch.steckdose_gewachshaus_heizung_switch";
              powerEntity = "sensor.steckdose_gewachshaus_heizung_power";
              currentEntity = "sensor.steckdose_gewachshaus_heizung_current";
            })
          ])
          (ha.mkGridSection [
            (ha.mkPowerStack {
              title = "Wasserpumpe";
              switchEntity = "switch.steckdose_wasserpumpe_switch";
              powerEntity = "sensor.steckdose_wasserpumpe_power";
              currentEntity = "sensor.steckdose_wasserpumpe_current";
            })
          ])
          (ha.mkGridSection [
            (ha.mkPowerStack {
              title = "Serverschrank";
              switchEntity = "switch.steckdose_serverschrank_switch";
              historyEntity = "select.steckdose_serverschrank_power_on_state";
              historyExtra = {
                fit_y_data = false;
                logarithmic_scale = false;
              };
              powerEntity = "sensor.steckdose_serverschrank_power";
              currentEntity = "sensor.steckdose_serverschrank_current";
              upperCurrent = 10;
              extraCards = [
                {
                  type = "entities";
                  title = "Steckdose Serverschrank";
                  entities = [
                    {
                      entity = "sensor.steckdose_serverschrank_current";
                      name = "Current";
                    }
                    {
                      entity = "sensor.steckdose_serverschrank_power";
                      name = "Power";
                    }
                    {
                      entity = "sensor.steckdose_serverschrank_summation_delivered";
                      name = "Summation delivered";
                    }
                    {
                      entity = "sensor.steckdose_serverschrank_voltage";
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
