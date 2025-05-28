{ lib, ... }:
{
  options.defaultWallpaper = lib.mkOption {
    type = lib.types.path;
    default = null;
    description = "Path to the chosen background image";
  };
}
