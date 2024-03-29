{ lib, config, ... }:

let
  cfg = config.iconsProfile;
in
{
  options.iconsProfile = {
    enable = lib.mkEnableOption "Whether to enable icon profiles";
    name = lib.mkOption {
      type = lib.types.str;
      default = null;
      description = "Name of the icons theme";
      example = "Adwaita";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = null;
      description = "Package for the icons theme";
      example = "pkgs.gnome.adwaita-icon-theme";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.enable cfg.name cfg.package ];
  };
}
