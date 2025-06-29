{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop.musescore;
in
{
  options.desktop.musescore.enable = lib.mkEnableOption "enable MuseScore & MuseSounds";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      musescore
      muse-sounds-manager
    ];
  };
}
