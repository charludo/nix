{ lib, config, ... }:
let
  cfg = config.hass.buttons;

  # SNZB-01P standard quirk command mapping. Verify with HA's Developer
  # Tools → Events listener if you ever add a button model that emits
  # different commands.
  pressCommand = {
    single = "toggle";
    double = "on";
    long = "off";
  };

  pressAttr =
    name: press:
    lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      default = [ ];
      description = "Action sequence for ${press} press of ${name}";
    };

  buttonSubmodule = lib.types.submodule (
    { name, ... }:
    {
      options = {
        single = pressAttr name "single";
        double = pressAttr name "double";
        long = pressAttr name "long";
      };
    }
  );

  ieeeOf =
    deviceName:
    let
      dev = config.hass.devices.zigbee.${deviceName} or null;
    in
    if dev == null then
      throw "hass.buttons: no hass.devices.zigbee entry named \"${deviceName}\""
    else
      lib.toLower dev.id;

  mkAutomation =
    name: btn:
    let
      branchFor =
        press: actions:
        lib.optionals (actions != [ ]) [
          {
            conditions = [
              {
                condition = "template";
                value_template = "{{ trigger.event.data.command == '${pressCommand.${press}}' }}";
              }
            ];
            sequence = actions;
          }
        ];
      branches =
        branchFor "single" btn.single ++ branchFor "double" btn.double ++ branchFor "long" btn.long;
    in
    {
      alias = "Button: ${name}";
      # `restart` so a new press cancels any pending action from a
      # previous one (e.g. the 5-min waterpump auto-off can be aborted
      # by a single press toggling it off).
      mode = "restart";
      trigger = [
        {
          platform = "event";
          event_type = "zha_event";
          event_data.device_ieee = ieeeOf name;
        }
      ];
      action = [ { choose = branches; } ];
    };
in
{
  options.hass.buttons = lib.mkOption {
    default = { };
    description = ''
      Zigbee push-button automations driven by zha_event. Each entry's
      key must match a `hass.devices.zigbee` entry — use
      `e.zigbee.<slug>` as the key so the device name is never typed
      twice. The IEEE is resolved from `hass.devices.zigbee`.
    '';
    type = lib.types.attrsOf buttonSubmodule;
  };

  config.hass.automations = lib.mapAttrs' (
    name: btn: lib.nameValuePair "button_${lib.ha.mkSlug name}" (mkAutomation name btn)
  ) cfg;
}
