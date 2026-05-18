{ lib, config, ... }:
let
  cfg = config.hass;
  mkSlug = lib.ha.mkSlug;

  areaOption = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "Home Assistant area name this entity belongs to";
  };

  withAreaSubmodule = lib.types.submodule {
    options.area = areaOption;
  };

  zigbeeDeviceSubmodule = lib.types.submodule {
    options = {
      id = lib.mkOption {
        type = lib.types.str;
        description = "Zigbee MAC address in colon-separated form, e.g. 00:15:8d:00:09:45:19:da";
      };
      area = lib.mkOption {
        type = lib.types.str;
        description = "Home Assistant area this device belongs to";
      };
      binary_sensor = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Binary sensor sub-entity names exposed by the device";
      };
      diagnostic = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Diagnostic sensor names (battery etc.); generated under the sensor domain";
      };
      light = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Light sub-entity names exposed by the device";
      };
      number = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Number sub-entity names exposed by the device";
      };
      select = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Select sub-entity names exposed by the device";
      };
      sensor = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Sensor sub-entity names exposed by the device";
      };
      switch = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Switch sub-entity names exposed by the device";
      };
    };
  };

  inputBooleanSubmodule = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Friendly name displayed in the UI";
      };
      icon = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "MDI icon for the input boolean";
      };
      initial = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Initial state on Home Assistant startup";
      };
      area = areaOption;
    };
  };

  inputNumberSubmodule = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Friendly name displayed in the UI";
      };
      min = lib.mkOption {
        type = lib.types.number;
        description = "Minimum allowed value";
      };
      max = lib.mkOption {
        type = lib.types.number;
        description = "Maximum allowed value";
      };
      step = lib.mkOption {
        type = lib.types.number;
        default = 1;
        description = "Step size used by sliders and increment/decrement actions";
      };
      initial = lib.mkOption {
        type = lib.types.nullOr lib.types.number;
        default = null;
        description = "Initial value on Home Assistant startup";
      };
      icon = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "MDI icon for the input number";
      };
      unit_of_measurement = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Unit suffix shown next to the value";
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
      if device.${nixKey} == [ ] then acc else acc // { ${haDomain} = existing // entries; }
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
    person = lib.mapAttrs' (
      name: _:
      let
        slug = mkSlug name;
      in
      lib.nameValuePair slug "person.${slug}"
    ) (cfg.persons or { });

    # Mobile-app phones produce notify-service strings, slugified from their
    # human-readable name (the Companion-app device name in HA).
    mobile_app = lib.mapAttrs' (
      name: _:
      let
        slug = mkSlug name;
      in
      lib.nameValuePair slug "notify.mobile_app_${slug}"
    ) cfg.devices.mobile_apps;

    # The mobile_app integration also creates a device_tracker entity per
    # paired phone, named after the same slug. Exposed here so persons can
    # reference it as e.device_tracker.<slug>.
    device_tracker = lib.mapAttrs' (
      name: _:
      let
        slug = mkSlug name;
      in
      lib.nameValuePair slug "device_tracker.${slug}"
    ) cfg.devices.mobile_apps;
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
        description = "Zigbee devices managed by ZHA, keyed by human-readable name";
      };
      input_booleans = lib.mkOption {
        type = lib.types.attrsOf inputBooleanSubmodule;
        default = { };
        description = "Declarative input_boolean helpers keyed by slug";
      };
      input_numbers = lib.mkOption {
        type = lib.types.attrsOf inputNumberSubmodule;
        default = { };
        description = "Declarative input_number helpers keyed by slug";
      };
      media_players = lib.mkOption {
        type = lib.types.attrsOf withAreaSubmodule;
        default = { };
        description = "Known media_player entities keyed by slug";
      };
      vacuums = lib.mkOption {
        type = lib.types.attrsOf withAreaSubmodule;
        default = { };
        description = "Known vacuum entities keyed by slug";
      };
      fans = lib.mkOption {
        type = lib.types.attrsOf withAreaSubmodule;
        default = { };
        description = "Known fan entities keyed by slug";
      };
      images = lib.mkOption {
        type = lib.types.attrsOf withAreaSubmodule;
        default = { };
        description = "Known image entities keyed by slug";
      };
      suns = lib.mkOption {
        type = lib.types.attrsOf withAreaSubmodule;
        default = { };
        description = "Known sun entities keyed by slug";
      };
      weathers = lib.mkOption {
        type = lib.types.attrsOf withAreaSubmodule;
        default = { };
        description = "Known weather entities keyed by slug";
      };
      sensors = lib.mkOption {
        type = lib.types.attrsOf withAreaSubmodule;
        default = { };
        description = "Extra sensors (template, statistics, integration-provided) referenced by slug";
      };
      mobile_apps = lib.mkOption {
        type = lib.types.attrsOf withAreaSubmodule;
        default = { };
        description = "Companion-app phones keyed by human-readable name, exposed as e.mobile_app.<slug> notify-service strings";
      };
    };

    entities = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      readOnly = true;
      description = "Type-safe entity ID tree indexed by HA domain then device/entity slug";
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
