{
  config,
  lib,
  ...
}:

with lib;
let
  cfg = config.graphicalFixes;
in
{
  options.graphicalFixes.enable = mkEnableOption "some graphical fixes";

  config = mkIf cfg.enable {
    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    };
  };
}
