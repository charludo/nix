{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.desktop.element;
  palette = lib.colors.extendPalette config.colorScheme.palette;
in
{
  options.desktop.element.enable = lib.mkEnableOption "enable Element Matrix client";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      element-desktop
    ];

    home.file.".config/Element/config.json".text = # json
      ''
        {
            "setting_defaults": {
                "custom_themes": [
                    {
                        "name": "Nix",
                        "is_dark": true,
                        "colors": {
                            "accent-color": "${palette.base0B}",
                            "accent": "${palette.base0B}",
                            "primary-color": "${palette.base0D}",
                            "warning-color": "${palette.base08}d9",
                            "alert": "${palette.base07}",
                            "timeline-background-color": "${palette.base00}",
                            "roomlist-background-color": "${palette.darker_black}",
                            "sidebar-color": "${palette.darkest_black}",
                            "timeline-highlights-color": "${palette.base01}22",
                            "roomlist-highlights-color": "${palette.base02}52",
                            "roomlist-separator-color": "${palette.base04}",
                            "togglesw-off-color": "${palette.base04}",
                            "roomlist-text-secondary-color": "${palette.base06}",
                            "timeline-text-secondary-color": "${palette.base0D}",
                            "roomlist-text-color": "${palette.base07}",
                            "timeline-text-color": "${palette.base07}",
                            "secondary-content": "${palette.base06}",
                            "tertiary-content": "${palette.base05}",
                            "reaction-row-button-selected-bg-color": "${palette.base0D}",
                            "menu-selected-color": "${palette.base08}",
                            "focus-bg-color": "${palette.base0D}",
                            "room-highlight-color": "${palette.base0D}",
                            "other-user-pill-bg-color": "${palette.base0D}",
                            "eventbubble-self-bg": "${palette.dark_blue}80",
                            "eventbubble-others-bg": "${palette.black2}",
                            "eventbubble-bg-hover": "#${palette.base01}22",
                            "avatar-background-colors": [
                                "${palette.base08}",
                                "${palette.base09}",
                                "${palette.base0A}",
                                "${palette.base0B}",
                                "${palette.base0C}",
                                "${palette.base0D}",
                                "${palette.base0E}",
                                "${palette.base0F}"
                            ]
                        }
                    }
                ]
            },
            "show_labs_settings": true
        }
      '';
  };
}
