{ config, pkgs, ... }:
{
  fontProfiles = {
    enable = true;
    monospace = {
      family = "GeistMono Nerd Font";
      # package = pkgs.nerd-fonts.fira-code;
      # package = pkgs.nerd-fonts.lilex;
      package = pkgs.nerd-fonts.geist-mono;
    };
    regular = {
      family = "Cantarell";
      package = pkgs.cantarell-fonts;
    };
  };

  cursorProfile = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };

  iconsProfile = {
    package = pkgs.oranchelo-icon-theme;
    name = "Oranchelo";
  };

  home.packages = [
    pkgs.noto-fonts-color-emoji
  ];

  home.sessionVariables = {
    XCURSOR_THEME = config.cursorProfile.name;
    XCURSOR_SIZE = config.cursorProfile.size;
  };

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    name = config.cursorProfile.name;
    package = config.cursorProfile.package;
    size = config.cursorProfile.size;
  };
}
