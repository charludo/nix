{ lib, config, ... }:

let
  cfg = config.iconsProfile;
in
{
  options.iconsProfile = {
    enable = lib.mkEnableOption "icon profiles";
    name = lib.mkOption {
      type = lib.types.str;
      description = "Name of the icons theme";
      example = "Adwaita";
    };
    package = lib.mkOption {
      type = lib.types.package;
      description = "Package for the icons theme";
      example = "pkgs.gnome.adwaita-icon-theme";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    gtk.iconTheme.package = cfg.package;
    gtk.iconTheme.name = "${cfg.name}";
  };
}
