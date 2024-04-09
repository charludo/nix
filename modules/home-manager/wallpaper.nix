{ lib, ... }:
{
  options.defaultWallpaper = lib.mkOption {
    type = lib.types.str;
    default = null;
    description = "Path to the chosen background image";
    example = "/home/user/background.png";
  };
}
