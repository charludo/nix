{ pkgs, ... }:
{
  fontProfiles = {
    enable = true;
    monospace = {
      family = "FiraCode Nerd Font";
      package = pkgs.nerdfonts.override { fonts = [ "FiraCode" ]; };
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
}
