{ lib, config, ... }:
let
  cfg = config.hass;
  mkSlug = lib.ha.mkSlug;

  areaOption = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Home Assistant area name this entity belongs to.";
  };

  withAreaSubmodule = lib.types.submodule {
    options.area = areaOption;
  };

  zigbeeDeviceSubmodule = lib.types.submodule {
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
        description = "Diagnostic sensors (battery, etc.). Entity IDs are generated under the `sensor.` domain.";
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

  # Maps the nix-side zigbee device sub-key to its HA entity domain.
  # `diagnostic` (battery, etc.) emits entities under the `sensor.` domain.
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
      if device.${nixKey} == [ ] then
        acc
      else
        acc // { ${haDomain} = existing // entries; }
    ) { } (lib.attrNames zigbeeDomainMap);

  # Aggregate: domain -> deviceSlug -> { device, <subEntities> }
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

  # Simple, single-entity "devices": each slug maps to a plain entity ID string.
  simpleEntities = {
    input_boolean = lib.mapAttrs (slug: _: "input_boolean.${slug}") cfg.devices.input_booleans;
    input_number = lib.mapAttrs (slug: _: "input_number.${slug}") cfg.devices.input_numbers;
    media_player = lib.mapAttrs (slug: _: "media_player.${slug}") cfg.devices.media_players;
    vacuum = lib.mapAttrs (slug: _: "vacuum.${slug}") cfg.devices.vacuums;
    fan = lib.mapAttrs (slug: _: "fan.${slug}") cfg.devices.fans;
    image = lib.mapAttrs (slug: _: "image.${slug}") cfg.devices.images;
    sun = lib.mapAttrs (slug: _: "sun.${slug}") cfg.devices.suns;
    weather = lib.mapAttrs (slug: _: "weather.${slug}") cfg.devices.weathers;
    sensor = lib.mapAttrs (slug: _: "sensor.${slug}") cfg.devices.sensors;
    script = lib.mapAttrs (slug: _: "script.${slug}") cfg.scripts;
    automation = lib.mapAttrs (slug: _: "automation.${slug}") cfg.automations;
    area = lib.mapAttrs' (name: _: lib.nameValuePair (mkSlug name) (mkSlug name)) cfg.areas;
  };

  # Final entities tree: zigbee (with sub-entities) and simple entities coexist
  # in the same domain (e.g. e.sensor has both attrset entries from zigbee
  # devices and string entries from extra sensors).
  allDomains = lib.unique ((lib.attrNames zigbeeEntities) ++ (lib.attrNames simpleEntities));

  mergedEntities = lib.genAttrs allDomains (
    domain: (zigbeeEntities.${domain} or { }) // (simpleEntities.${domain} or { })
  );
in
{
  options.hass = {
    devices = {
      zigbee = lib.mkOption {
        type = lib.types.attrsOf zigbeeDeviceSubmodule;
        default = { };
        description = "Zigbee devices managed by ZHA. Entity IDs are derived from the device name slug.";
      };
      input_booleans = lib.mkOption {
        type = lib.types.attrsOf inputBooleanSubmodule;
        default = { };
      };
      input_numbers = lib.mkOption {
        type = lib.types.attrsOf inputNumberSubmodule;
        default = { };
      };
      media_players = lib.mkOption {
        type = lib.types.attrsOf withAreaSubmodule;
        default = { };
      };
      vacuums = lib.mkOption {
        type = lib.types.attrsOf withAreaSubmodule;
        default = { };
      };
      fans = lib.mkOption {
        type = lib.types.attrsOf withAreaSubmodule;
        default = { };
      };
      images = lib.mkOption {
        type = lib.types.attrsOf withAreaSubmodule;
        default = { };
      };
      suns = lib.mkOption {
        type = lib.types.attrsOf withAreaSubmodule;
        default = { };
      };
      weathers = lib.mkOption {
        type = lib.types.attrsOf withAreaSubmodule;
        default = { };
      };
      sensors = lib.mkOption {
        type = lib.types.attrsOf withAreaSubmodule;
        default = { };
        description = "Extra sensors (template, statistics, integration-provided) referenced by slug.";
      };
    };

    entities = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      readOnly = true;
      description = ''
        Type-safe entity ID tree, indexed by HA domain then device/entity slug.

        For zigbee devices, each slug holds an attrset:
          e.sensor.thermometer_wohnzimmer.temperature  # "sensor.thermometer_wohnzimmer_temperature"
          e.sensor.thermometer_wohnzimmer.device       # "thermometer_wohnzimmer"  (slug only)

        For simple entities (one per slug), each slug holds the entity ID string:
          e.vacuum.botty                # "vacuum.botty"
          e.input_boolean.turalarm      # "input_boolean.turalarm"
          e.script.botty_zurueckkehren  # "script.botty_zurueckkehren"
      '';
    };
  };

  config = {
    hass.entities = mergedEntities;

    services.home-assistant.config = {
      input_boolean = lib.mapAttrs (
        _: v:
        lib.filterAttrs (_: x: x != null) {
          inherit (v) name icon initial;
        }
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
