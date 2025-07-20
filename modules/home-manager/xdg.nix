{ config, lib, ... }:
let
  cfg = config.xdgProfile;
in
{
  options.xdgProfile.enable = lib.mkEnableOption "XDG customizations";

  config = lib.mkIf cfg.enable {
    xdg.userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "${config.home.homeDirectory}";
      documents = "${config.home.homeDirectory}/Documents";
      download = "${config.home.homeDirectory}/Downloads";
      music = "${config.home.homeDirectory}/Music";
      pictures = "${config.home.homeDirectory}/Pictures";
      publicShare = "${config.home.homeDirectory}";
      templates = "${config.home.homeDirectory}";
      videos = "${config.home.homeDirectory}/Videos";
      extraConfig = {
        XDG_PROJECTS_DIR = "${config.home.homeDirectory}/Projekte";
      };
    };
  };
}
