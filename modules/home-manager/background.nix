{ lib, config, ... }:

let
  cfg = config.iconsProfile;
in
{
  options.background = lib.mkOption {
    type = lib.types.str;
    default = null;
    description = "Path to the chosen background image";
    example = "/home/user/background.png";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.background ];
  };
}
