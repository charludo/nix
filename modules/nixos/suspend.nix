{
  config,
  lib,
  ...
}:

with lib;
let
  cfg = config.suspend;
in
{
  options.suspend = {
    enable = lib.mkEnableOption "custom suspend options";

    powertop = mkOption {
      type = types.bool;
      default = false;
      description = "enable powertop";
    };

    gigabyteFix = mkOption {
      type = types.bool;
      default = false;
      description = "enable fix for B550i motherboard";
    };
  };

  config = mkIf cfg.enable {
    powerManagement.enable = true;
    powerManagement.powertop.enable = cfg.powertop;
  };
}
