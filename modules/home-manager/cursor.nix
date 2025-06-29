{ lib, config, ... }:

let
  cfg = config.cursorProfile;
in
{
  options.cursorProfile = {
    enable = lib.mkEnableOption "Whether to enable icon profiles";
    name = lib.mkOption {
      type = lib.types.str;
      description = "Name of the cursor theme";
      example = "Adwaita";
    };
    size = lib.mkOption {
      type = lib.types.int;
      description = "Size of the cursor";
      example = 24;
    };
    package = lib.mkOption {
      type = lib.types.package;
      description = "Package for the cursor theme";
      example = "pkgs.gnome.adwaita-icon-theme";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.pointerCursor = {
      gtk.enable = true;
      x11.enable = true;
      name = cfg.name;
      package = cfg.package;
      size = cfg.size;
    };

    home.sessionVariables = {
      XCURSOR_THEME = cfg.name;
      XCURSOR_SIZE = cfg.size;
    };

    gtk.cursorTheme.package = cfg.package;
    gtk.cursorTheme.name = "${cfg.name}";
    gtk.cursorTheme.size = cfg.size;
  };
}
