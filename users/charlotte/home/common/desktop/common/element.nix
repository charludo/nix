{ pkgs, config, lib, ... }:
let
  colors = import ../../nvim/colors.nix { inherit config lib; };
in
{
  home.packages = with pkgs; [
    element-desktop
  ];

  home.file.".config/Element/config.json".text = /* json */ ''
    {
        "setting_defaults": {
            "custom_themes": [
                {
                    "name": "Nix",
                    "is_dark": true,
                    "colors": {
                        "accent-color": "${colors.base09}",
                        "accent": "${colors.base09}",
                        "primary-color": "${colors.base0D}",
                        "warning-color": "${colors.base08}d9",
                        "alert": "${colors.base08}d9",
                        "timeline-background-color": "${colors.base00}",
                        "roomlist-background-color": "${colors.darker_black}",
                        "sidebar-color": "${colors.darkest_black}",
                        "timeline-highlights-color": "${colors.base01}22",
                        "roomlist-highlights-color": "${colors.base02}52",
                        "roomlist-separator-color": "${colors.base04}",
                        "togglesw-off-color": "${colors.base04}",
                        "roomlist-text-secondary-color": "${colors.base06}",
                        "timeline-text-secondary-color": "${colors.base0D}",
                        "roomlist-text-color": "${colors.base07}",
                        "timeline-text-color": "${colors.base07}",
                        "secondary-content": "${colors.base06}",
                        "tertiary-content": "${colors.base05}",
                        "reaction-row-button-selected-bg-color": "${colors.base0D}",
                        "menu-selected-color": "${colors.base08}",
                        "focus-bg-color": "${colors.base0D}",
                        "room-highlight-color": "${colors.base0D}",
                        "other-user-pill-bg-color": "${colors.base0D}",
                        "eventbubble-self-bg": "${colors.dark_blue}80",
                        "eventbubble-others-bg": "${colors.black2}",
                        "eventbubble-bg-hover": "#${colors.base01}22",
                        "avatar-background-colors": [
                            "${colors.base08}",
                            "${colors.base09}",
                            "${colors.base0A}",
                            "${colors.base0B}",
                            "${colors.base0C}",
                            "${colors.base0D}",
                            "${colors.base0E}",
                            "${colors.base0F}"
                        ]
                    }
                }
            ]
        },
        "show_labs_settings": true
    }
  '';
}
