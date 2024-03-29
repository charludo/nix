{ lib, config, ... }:

let
  cfg = config.cursorProfile;
in
{
  options.cursorProfile = {
    enable = lib.mkEnableOption "Whether to enable icon profiles";
    name = lib.mkOption {
      type = lib.types.str;
      default = null;
      description = "Name of the cursor theme";
      example = "Adwaita";
    };
    size = lib.mkOption {
      type = lib.types.int;
      default = null;
      description = "Size of the cursor";
      example = "24";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = null;
      description = "Package for the cursor theme";
      example = "pkgs.gnome.adwaita-icon-theme";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.enable cfg.name cfg.size cfg.package ];
  };
}
