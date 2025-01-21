{ config, lib, ... }:

with lib;
let
  cfg = config.nicerFonts;
in
{
  options.nicerFonts = {
    enable = lib.mkEnableOption (lib.mdDoc "enable nicer font rendering on desktops");
  };

  config = mkIf cfg.enable {
    fonts.fontconfig = {
      enable = true;

      antialias = true;

      subpixel.lcdfilter = "default";

      allowBitmaps = true;
      useEmbeddedBitmaps = true;

      hinting = {
        enable = true;
        style = "none";
        autohint = false;
      };
    };
  };
}
