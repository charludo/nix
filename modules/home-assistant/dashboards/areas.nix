{
  pkgs,
  lib,
  config,
  ...
}:
let
  ha = lib.ha;
  cfg = config.hass;
  e = cfg.entities;

  tempDevicesInArea =
    areaName:
    lib.filterAttrs (
      _: device:
      device.area == areaName
      && lib.elem "temperature" (device.sensor or [ ])
      && lib.elem "humidity" (device.sensor or [ ])
    ) cfg.devices.zigbee;

  powerDevicesInArea =
    areaName:
    lib.filterAttrs (
      _: device:
      device.area == areaName
      && lib.elem "power" (device.sensor or [ ])
      && lib.elem "current" (device.sensor or [ ])
    ) cfg.devices.zigbee;

  mkAreaView =
    name: area:
    let
      tempDevices = tempDevicesInArea name;
      powerDevices = powerDevicesInArea name;
      hasTempDevices = tempDevices != { };
      hasPowerDevices = powerDevices != { };
      areaSlug = ha.mkSlug name;
    in
    {
      type = "sections";
      max_columns = 3;
      path = areaSlug;
      icon = area.icon;
      badges = [ ];
      header = ha.mkViewHeader name;
      sections =
        lib.optionals hasTempDevices [
          (ha.mkGridSection (
            [ (ha.mkMushTitle "Temperatur") ]
            ++ (lib.mapAttrsToList (
              deviceName: _:
              ha.mkTempHumPlot {
                name = deviceName;
                tempEntity = e.sensor.${ha.mkSlug deviceName}.temperature;
                humEntity = e.sensor.${ha.mkSlug deviceName}.humidity;
              }
            ) tempDevices)
          ))
        ]
        ++ lib.optionals hasPowerDevices [
          (ha.mkGridSection (
            [ (ha.mkMushTitle "Energieverbrauch") ]
            ++ (lib.mapAttrsToList (
              deviceName: _:
              ha.mkPowerPlot {
                name = deviceName;
                powerEntity = e.sensor.${ha.mkSlug deviceName}.power;
                currentEntity = e.sensor.${ha.mkSlug deviceName}.current;
              }
            ) powerDevices)
          ))
        ]
        ++ [
          (ha.mkGridSection [
            (ha.mkMushTitle "Alle Geräte")
            {
              type = "custom:auto-entities";
              card = {
                type = "entities";
                show_header_toggle = true;
              };
              filter = {
                include = [
                  {
                    area = e.area.${areaSlug};
                    options = { };
                  }
                ];
                exclude = [ ];
              };
              sort = {
                method = "device";
                numeric = false;
              };
            }
          ])
        ];
    };

  sortedAreas = lib.sort (a: b: a.value.order < b.value.order) (
    lib.mapAttrsToList lib.nameValuePair cfg.areas
  );

  dashboardCfg = (pkgs.formats.yaml { }).generate "dashboard-areas.yaml" {
    views = map (nv: mkAreaView nv.name nv.value) sortedAreas;
  };
in
{
  systemd.tmpfiles.rules = [
    "L+ /var/lib/hass/dashboard-areas.yaml - - - - ${dashboardCfg}"
  ];

  services.home-assistant.config.lovelace.dashboards.dashboard-areas = {
    mode = "yaml";
    filename = "dashboard-areas.yaml";
    title = "Räume";
    icon = "mdi:floor-plan";
    show_in_sidebar = true;
    require_admin = false;
  };
}
