{ lib, config, ... }:
let
  cfg = config.hass;
  mkSlug = lib.ha.mkSlug;

  mkId = id: "0x${lib.replaceStrings [ ":" ] [ "" ] id}";

  domainList = [
    "binary_sensor"
    "diagnostic"
    "light"
    "number"
    "select"
    "sensor"
    "switch"
  ];

  mkDeviceEntities =
    _: device:
    lib.foldl'
      (
        acc: domain:
        if lib.hasAttr domain device then
          acc
          // {
            ${domain} = lib.genAttrs device.${domain} (entity: "${domain}.${mkId device.id}_${entity}");
          }
        else
          acc
      )
      {
        id = mkId device.id;
        area = device.area;
      }
      domainList;

  mkEntities =
    devices:
    lib.foldl' (
      domainAcc: deviceName:
      let
        slug = mkSlug deviceName;
        deviceEntities = mkDeviceEntities deviceName devices.${deviceName};
      in
      lib.foldl' (
        acc: domain:
        if lib.hasAttr domain deviceEntities then
          acc
          // {
            ${domain} = (acc.${domain} or { }) // {
              ${slug} = deviceEntities.${domain};
            };
          }
        else
          acc
      ) domainAcc domainList
    ) { } (lib.attrNames devices);

  deviceSubmodule = lib.types.submodule {
    options = {
      id = lib.mkOption {
        type = lib.types.str;
        description = "Zigbee MAC address (colon-separated), e.g. 00:15:8d:00:09:45:19:da";
      };
      area = lib.mkOption {
        type = lib.types.str;
        description = "Home Assistant area name";
      };
      binary_sensor = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      diagnostic = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      light = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      number = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      select = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      sensor = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      switch = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
    };
  };
in
{
  options.hass = {
    devices = lib.mkOption {
      type = lib.types.attrsOf deviceSubmodule;
      default = { };
      description = "Zigbee devices managed by ZHA. Entity IDs are derived automatically from MAC addresses.";
    };

    entities = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      readOnly = true;
      description = "Derived entity ID attrset, indexed by domain then device name.";
    };
  };

  config.hass.entities = mkEntities cfg.devices;
}
