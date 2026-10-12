{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  colors.base = lib.mkDefault inputs.nix-colors.colorSchemes.primer-dark-dimmed.palette;

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
    serif = {
      family = "DejaVu Serif";
      package = pkgs.dejavu_fonts;
    };
    emoji = {
      family = "Noto Color Emoji";
      package = pkgs.noto-fonts-color-emoji;
    };
    japanese = {
      family = "Noto Sans CJK JP";
      package = pkgs.noto-fonts-cjk-sans-static;
    };
    japanese_serif = {
      family = "Noto Serif CJK JP";
      package = pkgs.noto-fonts-cjk-serif-static;
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
