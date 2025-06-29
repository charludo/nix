{ config, lib, ... }:
let
  cfg = config.desktop.qtProfile;
in
{
  options.desktop.qtProfile.enable = lib.mkEnableOption "enable qt customizations";

  config = lib.mkIf cfg.enable {
    qt = {
      enable = true;
      style.name = "adwaita-dark";
      platformTheme.name = "adwaita";
    };
  };
}
