{ lib, config, ... }:
let
  cfg = config.hass;
  inherit (lib.ha) mkSlug;
in
{
  options.hass.entities = lib.mkOption {
    type = lib.types.lazyAttrsOf (lib.types.lazyAttrsOf lib.types.anything);
    readOnly = true;
    description = "Type-safe entity ID tree indexed by HA domain then device/entity slug";
  };

  config.hass.entities = lib.mkMerge (
    lib.concatLists (
      lib.mapAttrsToList (
        deviceName: device:
        [ { zigbee.${mkSlug deviceName} = deviceName; } ]
        ++
          lib.mapAttrsToList
            (
              nixKey: haDomain:
              lib.optionalAttrs (device.${nixKey} != [ ]) {
                ${haDomain}.${mkSlug deviceName} = {
                  device = mkSlug deviceName;
                }
                // lib.genAttrs device.${nixKey} (
                  e:
                  if e == haDomain then
                    "${haDomain}.${mkSlug deviceName}"
                  else
                    "${haDomain}.${mkSlug deviceName}_${e}"
                );
              }
            )
            {
              binary_sensor = "binary_sensor";
              diagnostic = "sensor";
              light = "light";
              number = "number";
              select = "select";
              sensor = "sensor";
              switch = "switch";
            }
      ) cfg.devices.zigbee
    )

    ++
      lib.mapAttrsToList
        (domain: source: {
          ${domain} = lib.mapAttrs (slug: _: "${domain}.${slug}") source;
        })
        {
          input_boolean = cfg.devices.input_booleans;
          input_number = cfg.devices.input_numbers;
          media_player = cfg.devices.media_players;
          vacuum = cfg.devices.vacuums;
          fan = cfg.devices.fans;
          image = cfg.devices.images;
          sun = cfg.devices.suns;
          weather = cfg.devices.weathers;
          sensor = cfg.devices.sensors;
          script = cfg.scripts;
          automation = cfg.automations;
          timer = cfg.timers;
        }
    ++ [
      {
        area = lib.mapAttrs' (
          name: _:
          lib.nameValuePair (mkSlug name) {
            slug = mkSlug name;
            inherit name;
          }
        ) cfg.areas;
      }

      {
        person = lib.mapAttrs' (
          name: p:
          lib.nameValuePair (mkSlug name) {
            entity_id = "person.${mkSlug name}";
            notify = if p.phone == null then null else "notify.mobile_app_${mkSlug p.phone}";
            device_tracker = if p.phone == null then null else "device_tracker.${mkSlug p.phone}";
          }
        ) (cfg.persons or { });
      }
    ]
  );
}
