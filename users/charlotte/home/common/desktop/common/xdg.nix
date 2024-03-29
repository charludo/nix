{ config, ... }:
{
  xdg.desktopEntries.code = {
    name = "Code";
    type = "Application";
    comment = "Open NeoVim inside terminal";
    terminal = false;
    exec = "alacritty -e nvim";
    categories = [ "Development" "Utility" ];
    icon = "nvim";
    mimeType = [ "text/*" ];
  };
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
      XDG_WEBDESIGN_DIR = "${config.home.homeDirectory}/Webdesign";
    };
  };
}
