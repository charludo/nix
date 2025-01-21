{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.screensharing;
in
{
  options.screensharing = {
    enable = lib.mkEnableOption (
      lib.mdDoc "enable everything necessary to get screensharing working under wayland"
    );
  };

  config = mkIf cfg.enable {
    xdg.portal = {
      enable = true;
      wlr = {
        enable = true;
        settings = {
          screencast = {
            chooser_type = "simple";
            chooser_cmd = "${pkgs.slurp}/bin/slurp -f %o -ro";
          };
        };
      };
      config.common.default = [ "hyprland" ];
      extraPortals = with pkgs; [
        xdg-desktop-portal-wlr
        xdg-desktop-portal-hyprland
      ];
    };
  };
}
