{
  config,
  lib,
  ...
}:

with lib;
let
  cfg = config.wacom;
in
{
  options.wacom = {
    enable = mkEnableOption "wacom tablet pad button remapping";

    padName = mkOption {
      type = types.str;
      default = "Wacom Intuos PT M Pad";
      description = "evdev name of the tablet's pad, see `evremap list-devices`";
    };

    buttons = mkOption {
      type = types.attrsOf (types.listOf types.str);
      default = {
        BTN_LEFT = [ "KEY_LEFTSHIFT" ];
        BTN_RIGHT = [ "KEY_F13" ];
        BTN_FORWARD = [
          "KEY_LEFTCTRL"
          "KEY_LEFTSHIFT"
        ];
        BTN_BACK = [
          "KEY_LEFTCTRL"
          "KEY_Z"
        ];
      };
      description = "pad buttons mapped to the keys they hold while pressed, see `evremap list-keys`";
    };
  };

  config = mkIf cfg.enable {
    services.evremap = {
      enable = true;
      settings = {
        device_name = cfg.padName;
        remap = mapAttrsToList (input: output: {
          input = [ input ];
          inherit output;
        }) cfg.buttons;
      };
    };
  };
}
