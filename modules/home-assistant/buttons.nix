{ lib, config, ... }:
let
  cfg = config.hass.buttons;
in
{
  options.hass.buttons = lib.mkOption {
    default = { };
    description = "Zigbee push-button automations driven by zha_event";
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            single = lib.mkOption {
              type = lib.types.listOf lib.types.anything;
              default = [ ];
              description = "Action sequence for single press of ${name}";
            };
            double = lib.mkOption {
              type = lib.types.listOf lib.types.anything;
              default = [ ];
              description = "Action sequence for double press of ${name}";
            };
            long = lib.mkOption {
              type = lib.types.listOf lib.types.anything;
              default = [ ];
              description = "Action sequence for long press of ${name}";
            };
          };
        }
      )
    );
  };

  config.hass.automations = lib.mapAttrs' (
    name: btn:
    lib.nameValuePair "button_${lib.ha.mkSlug name}" {
      alias = "Button: ${name}";
      mode = "restart";
      trigger = [
        {
          platform = "event";
          event_type = "zha_event";
          event_data.device_ieee = lib.toLower (
            (config.hass.devices.zigbee.${name}
              or (throw "hass.buttons: no hass.devices.zigbee entry named \"${name}\"")
            ).id
          );
        }
      ];
      action = [
        {
          choose =
            lib.concatMap
              (
                {
                  press,
                  command,
                }:
                lib.optionals (btn.${press} != [ ]) [
                  {
                    conditions = [
                      {
                        condition = "template";
                        value_template = "{{ trigger.event.data.command == '${command}' }}";
                      }
                    ];
                    sequence = btn.${press};
                  }
                ]
              )
              [
                {
                  press = "single";
                  command = "toggle";
                }
                {
                  press = "double";
                  command = "on";
                }
                {
                  press = "long";
                  command = "off";
                }
              ];
        }
      ];
    }
  ) cfg;
}
