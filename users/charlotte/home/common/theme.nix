{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  colorScheme = lib.mkDefault inputs.nix-colors.colorSchemes.primer-dark-dimmed;

  fontProfiles = {
    enable = true;
    monospace = {
      family = "GeistMono Nerd Font";
      package = pkgs.nerd-fonts.geist-mono;
      size = lib.mkDefault 14;
    };
    regular = {
      family = "Cantarell";
      package = pkgs.cantarell-fonts;
    };
    emoji = {
      family = "Noto Color Emoji";
      package = pkgs.noto-fonts-color-emoji;
    };
  };

  cursorProfile = {
    enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };

  iconsProfile = {
    enable = true;
    package = pkgs.tela-icon-theme;
    name = "Tela";
  };
}
