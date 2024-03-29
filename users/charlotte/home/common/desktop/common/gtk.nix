{ config, pkgs, inputs, ... }:

let
  inherit (inputs.nix-colors.lib-contrib { inherit pkgs; }) gtkThemeFromScheme;
in
rec {
  gtk = {
    enable = true;

    cursorTheme.package = config.cursorProfile.package;
    cursorTheme.name = "${config.cursorProfile.name}";
    cursorTheme.size = config.cursorProfile.size;

    iconTheme.package = config.iconsProfile.package;
    iconTheme.name = "${config.iconsProfile.name}";

    theme.name = "${config.colorscheme.slug}";
    theme.package = gtkThemeFromScheme { scheme = config.colorscheme; };

    font.name = config.fontProfiles.regular.family;
    font.size = 11;

    gtk3.bookmarks = [
      "file://${config.xdg.userDirs.documents}"
      "file://${config.xdg.userDirs.extraConfig.XDG_PROJECTS_DIR}"
      "file:///media/NAS"
    ];
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  services.xsettingsd = {
    enable = true;
    settings = {
      "Net/ThemeName" = "${gtk.theme.name}";
      "Net/IconThemeName" = "${gtk.iconTheme.name}";
    };
  };
}
