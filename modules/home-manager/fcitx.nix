{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop.fcitx;
  palette = lib.colors.extendPalette config.colorScheme.palette;
  format = pkgs.formats.ini { };
in
{
  options.desktop.fcitx.enable = lib.mkEnableOption "fcitx5 input method (e.g. for Japanese)";

  config = lib.mkIf cfg.enable {
    fontProfiles.japanese = true;

    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";

      fcitx5 = {
        addons = with pkgs; [
          fcitx5-mozc
          fcitx5-gtk
        ];
        waylandFrontend = true;
        ignoreUserConfig = true;

        settings.inputMethod = {
          GroupOrder."0" = "Default";
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            DefaultIM = "mozc";
          };
          "Groups/0/Items/0".Name = "keyboard-us";
          "Groups/0/Items/1".Name = "mozc";
        };
        settings.addons = {
          classicui.globalSection.Theme = "nix";
          classicui.globalSection.DarkTheme = "nix";
          mozc.globalSection.Vertical = "False";
        };
      };
    };
    xdg.dataFile = {
      "fcitx5/themes/nix/theme.conf".source = format.generate "fcitx-theme" {
        Metadata = {
          Name = "nix";
          Version = "0.1";
          ScaleWithDPI = true;
        };

        InputPanel = {
          NormalColor = "${palette.base07}";
          HighlightCandidateColor = "${palette.darker_black}";
          HighlightColor = "${palette.darker_black}";
          HighlightBackgroundColor = "${palette.darker_black}";
          Spacing = 6;
        };

        "InputPanel/TextMargin" = {
          Left = 5;
          Right = 5;
          Top = 5;
          Bottom = 5;
        };

        "InputPanel/ContentMargin" = {
          Left = 2;
          Right = 2;
          Top = 2;
          Bottom = 2;
        };

        "InputPanel/Background" = {
          Color = "${palette.darker_black}";
        };

        "InputPanel/Highlight" = {
          Color = "${palette.base0D}";
        };

        "InputPanel/Background/Margin" = {
          Left = 2;
          Right = 2;
          Top = 2;
          Bottom = 2;
        };

        "InputPanel/Highlight/Margin" = {
          Left = 5;
          Right = 7;
          Top = 5;
          Bottom = 5;
        };

        Menu = {
          NormalColor = "${palette.darker_black}";
        };

        "Menu/Background" = {
          Color = "${palette.darker_black}";
        };

        "Menu/Highlight" = {
          Color = "${palette.base0D}";
        };

        "Menu/Separator" = {
          Color = "${palette.base0D}";
        };

        "Menu/Background/Margin" = {
          Left = 2;
          Right = 2;
          Top = 2;
          Bottom = 2;
        };

        "Menu/ContentMargin" = {
          Left = 2;
          Right = 2;
          Top = 2;
          Bottom = 2;
        };

        "Menu/Highlight/Margin" = {
          Left = 5;
          Right = 5;
          Top = 5;
          Bottom = 5;
        };

        "Menu/TextMargin" = {
          Left = 5;
          Right = 5;
          Top = 5;
          Bottom = 5;
        };
      };
    };

    home.sessionVariables = {
      GTK_IM_MODULE = "fcitx";
      QT_IM_MODULE = "fcitx";
      ANKI_WAYLAND = 1;
    };
  };
}
