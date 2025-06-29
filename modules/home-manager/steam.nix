{ config, lib, ... }:
let
  cfg = config.games.steam;
in
{
  options.games.steam.enable = lib.mkEnableOption "enable Steam in big picture mode";

  config = lib.mkIf cfg.enable {
    xdg.desktopEntries.steam = {
      name = "Steam";
      type = "Application";
      comment = "Application for managing and playing games on Steam";
      terminal = false;
      exec = "steam -bigpicture %U";
      categories = [
        "Network"
        "Game"
      ];
      icon = "steam";
    };
  };
}
