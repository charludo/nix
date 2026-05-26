{ lib, config, ... }:
let
  cfg = config.hass;
  inherit (lib.ha) mkSlug;

  areaOption = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "HA area this entity belongs to";
  };

  withAreaSubmodule = lib.types.submodule { options.area = areaOption; };

  zigbeeDeviceSubmodule = lib.types.submodule {
    options = {
      id = lib.mkOption {
        type = lib.types.str;
        description = "Zigbee IEEE address, colon-separated (e.g. 00:15:8d:00:09:45:19:da)";
      };
      area = lib.mkOption {
        type = lib.types.str;
        description = "HA area this device belongs to";
      };
      binary_sensor = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Binary-sensor sub-entity names";
      };
      diagnostic = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Diagnostic sub-entity names (battery, etc), emitted under the sensor domain";
      };
      light = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Light sub-entity names";
      };
      number = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Number sub-entity names";
      };
      select = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Select sub-entity names";
      };
      sensor = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Sensor sub-entity names";
      };
      switch = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Switch sub-entity names";
      };
    };
  };

  inputBooleanSubmodule = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Friendly name shown in the UI";
      };
      icon = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "MDI icon";
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
        description = "Friendly name shown in the UI";
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
        description = "Slider step size";
      };
      initial = lib.mkOption {
        type = lib.types.nullOr lib.types.number;
        default = null;
        description = "Initial value on Home Assistant startup";
      };
      icon = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "MDI icon";
      };
      unit_of_measurement = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Unit shown next to the value";
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
        # ZHA's primary entity in a domain has no per-entity suffix
        # (e.g. `light.strahler`, not `light.strahler_light`). We model
        # that by stripping the suffix when the user-declared name
        # equals the HA domain.
        entries = lib.genAttrs device.${nixKey} (
          e: if e == haDomain then "${haDomain}.${slug}" else "${haDomain}.${slug}_${e}"
        );
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

  # Slug → canonical zigbee device name. Lets call sites refer to a
  # device without re-typing its name (used by `hass.buttons` to point
  # at a `hass.devices.zigbee` entry; the helper resolves IEEE/area
  # from there).
  zigbeeDevices = lib.mapAttrs' (
    name: _: lib.nameValuePair (mkSlug name) name
  ) cfg.devices.zigbee;

  simpleEntities = {
    input_boolean = byKey "input_boolean" cfg.devices.input_booleans;
    input_number = byKey "input_number" cfg.devices.input_numbers;
    zigbee = zigbeeDevices;
    media_player = byKey "media_player" cfg.devices.media_players;
    vacuum = byKey "vacuum" cfg.devices.vacuums;
    fan = byKey "fan" cfg.devices.fans;
    image = byKey "image" cfg.devices.images;
    sun = byKey "sun" cfg.devices.suns;
    weather = byKey "weather" cfg.devices.weathers;
    sensor = byKey "sensor" cfg.devices.sensors;
    script = byKey "script" cfg.scripts;
    automation = byKey "automation" cfg.automations;
    timer = byKey "timer" cfg.timers;
    area = lib.mapAttrs' (name: _: lib.nameValuePair (mkSlug name) (mkSlug name)) cfg.areas;
    person = bySlugifiedKey "person" (cfg.persons or { });
    # Per-person handles derived from hass.persons.<Name>.phone, the
    # device name the companion app reports to HA. The mobile_app
    # integration registers `notify.mobile_app_<phone-slug>` and
    # `device_tracker.<phone-slug>` under that slug.
    persons = lib.mapAttrs (
      _: p:
      let
        slug = if p.phone == null then null else mkSlug p.phone;
      in
      {
        notify = if slug == null then null else "notify.mobile_app_${slug}";
        device_tracker = if slug == null then null else "device_tracker.${slug}";
      }
    ) (cfg.persons or { });
  };

  allDomains = lib.unique ((lib.attrNames zigbeeEntities) ++ (lib.attrNames simpleEntities));

  withAreaList =
    description:
    lib.mkOption {
      type = lib.types.attrsOf withAreaSubmodule;
      default = { };
      inherit description;
    };
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
      media_players = withAreaList "Known media_player entities keyed by slug";
      vacuums = withAreaList "Known vacuum entities keyed by slug";
      fans = withAreaList "Known fan entities keyed by slug";
      images = withAreaList "Known image entities keyed by slug";
      suns = withAreaList "Known sun entities keyed by slug";
      weathers = withAreaList "Known weather entities keyed by slug";
      sensors = withAreaList "Sensor entities (template, statistics, integration-provided) keyed by slug";
    };

    entities = lib.mkOption {
      # lazyAttrsOf at both levels so that accessing one sub-tree (e.g.
      # `e.zigbee.button_sofa` used as an attribute key in
      # `hass.buttons`) doesn't force the other sub-trees. Otherwise
      # `e.automation = byKey "automation" cfg.automations` is touched
      # transitively and forms a cycle through buttons → automations.
      type = lib.types.lazyAttrsOf (lib.types.lazyAttrsOf lib.types.anything);
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
