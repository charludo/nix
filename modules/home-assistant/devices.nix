{ lib, config, ... }:
let
  cfg = config.hass;
  inherit (lib.ha) mkSlug;

  areaOption = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
  };

  strList = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
  };

  withAreaSubmodule = lib.types.submodule { options.area = areaOption; };

  withAreaList = lib.mkOption {
    type = lib.types.attrsOf withAreaSubmodule;
    default = { };
  };

  zigbeeDeviceSubmodule = lib.types.submodule {
    options = {
      id = lib.mkOption {
        type = lib.types.str;
        description = "Zigbee IEEE address, colon-separated (e.g. 00:15:8d:00:09:45:19:da)";
      };
      area = lib.mkOption { type = lib.types.str; };
      binary_sensor = strList;
      diagnostic = strList;
      light = strList;
      number = strList;
      select = strList;
      sensor = strList;
      switch = strList;
    };
  };

  inputBooleanSubmodule = lib.types.submodule {
    options = {
      name = lib.mkOption { type = lib.types.str; };
      icon = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      initial = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
      };
      area = areaOption;
    };
  };

  inputNumberSubmodule = lib.types.submodule {
    options = {
      name = lib.mkOption { type = lib.types.str; };
      min = lib.mkOption { type = lib.types.number; };
      max = lib.mkOption { type = lib.types.number; };
      step = lib.mkOption {
        type = lib.types.number;
        default = 1;
      };
      initial = lib.mkOption {
        type = lib.types.nullOr lib.types.number;
        default = null;
      };
      icon = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      unit_of_measurement = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      area = areaOption;
    };
  };

  # diagnostic sub-entities live under the sensor domain in HA.
  zigbeeDomainMap = {
    binary_sensor = "binary_sensor";
    diagnostic = "sensor";
    light = "light";
    number = "number";
    select = "select";
    sensor = "sensor";
    switch = "switch";
  };

  # For one zigbee device, build the per-HA-domain attrset of entity IDs,
  # always including a `device` key holding the slug so consumers can refer
  # to the device itself (e.g. for area assignments).
  mkZigbeeDeviceEntities =
    name: device:
    let
      slug = mkSlug name;
    in
    lib.foldl' (
      acc: nixKey:
      let
        haDomain = zigbeeDomainMap.${nixKey};
        entries = lib.genAttrs device.${nixKey} (e: "${haDomain}.${slug}_${e}");
        existing = acc.${haDomain} or { device = slug; };
      in
      if device.${nixKey} == [ ] then acc else acc // { ${haDomain} = existing // entries; }
    ) { } (lib.attrNames zigbeeDomainMap);

  zigbeeEntities = lib.foldl' (
    domainAcc: deviceName:
    let
      slug = mkSlug deviceName;
      perDomain = mkZigbeeDeviceEntities deviceName cfg.devices.zigbee.${deviceName};
    in
    lib.foldl' (
      acc: haDomain:
      acc
      // {
        ${haDomain} = (acc.${haDomain} or { }) // {
          ${slug} = perDomain.${haDomain};
        };
      }
    ) domainAcc (lib.attrNames perDomain)
  ) { } (lib.attrNames cfg.devices.zigbee);

  # Slug used directly as the entity name (input_boolean.<slug> etc.) — for
  # attrsets whose keys are already valid entity-id slugs.
  byKey = domain: lib.mapAttrs (slug: _: "${domain}.${slug}");

  # Human-readable keys (e.g. "Phone Charlotte") get slugified into the
  # entity_id (`device_tracker.phone_charlotte`).
  bySlugifiedKey =
    domain: lib.mapAttrs' (name: _: lib.nameValuePair (mkSlug name) "${domain}.${mkSlug name}");

  simpleEntities = {
    input_boolean = byKey "input_boolean" cfg.devices.input_booleans;
    input_number = byKey "input_number" cfg.devices.input_numbers;
    media_player = byKey "media_player" cfg.devices.media_players;
    vacuum = byKey "vacuum" cfg.devices.vacuums;
    fan = byKey "fan" cfg.devices.fans;
    image = byKey "image" cfg.devices.images;
    sun = byKey "sun" cfg.devices.suns;
    weather = byKey "weather" cfg.devices.weathers;
    sensor = byKey "sensor" cfg.devices.sensors;
    script = byKey "script" cfg.scripts;
    automation = byKey "automation" cfg.automations;
    area = lib.mapAttrs' (name: _: lib.nameValuePair (mkSlug name) (mkSlug name)) cfg.areas;
    person = bySlugifiedKey "person" (cfg.persons or { });
    device_tracker = bySlugifiedKey "device_tracker" cfg.devices.mobile_apps;
    # mobile_app keys map to the notify-service id, not the device_tracker.
    mobile_app = lib.mapAttrs' (
      name: _: lib.nameValuePair (mkSlug name) "notify.mobile_app_${mkSlug name}"
    ) cfg.devices.mobile_apps;
  };

  allDomains = lib.unique ((lib.attrNames zigbeeEntities) ++ (lib.attrNames simpleEntities));
in
{
  options.hass = {
    devices = {
      zigbee = lib.mkOption {
        type = lib.types.attrsOf zigbeeDeviceSubmodule;
        default = { };
      };
      input_booleans = lib.mkOption {
        type = lib.types.attrsOf inputBooleanSubmodule;
        default = { };
      };
      input_numbers = lib.mkOption {
        type = lib.types.attrsOf inputNumberSubmodule;
        default = { };
      };
      media_players = withAreaList;
      vacuums = withAreaList;
      fans = withAreaList;
      images = withAreaList;
      suns = withAreaList;
      weathers = withAreaList;
      sensors = withAreaList;
      mobile_apps = withAreaList;
    };

    entities = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      readOnly = true;
      description = "Type-safe entity ID tree indexed by HA domain then device/entity slug";
    };
  };

  config = {
    hass.entities = lib.genAttrs allDomains (
      domain: (zigbeeEntities.${domain} or { }) // (simpleEntities.${domain} or { })
    );

    services.home-assistant.config = {
      input_boolean = lib.mapAttrs (
        _: v: lib.filterAttrs (_: x: x != null) { inherit (v) name icon initial; }
      ) cfg.devices.input_booleans;

      input_number = lib.mapAttrs (
        _: v:
        lib.filterAttrs (_: x: x != null) {
          inherit (v)
            name
            min
            max
            step
            initial
            icon
            unit_of_measurement
            ;
        }
      ) cfg.devices.input_numbers;
    };
  };
}
