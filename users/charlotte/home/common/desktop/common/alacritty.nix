{ config, ... }:
{
  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        size = 14;
        bold.family = "${config.fontProfiles.monospace.family}";
        bold.style = "Bold";
        normal.family = "${config.fontProfiles.monospace.family}";
        normal.style = "Regular";
      };
      window = {
        dynamic_padding = false;
        padding.x = 10;
        padding.y = 10;
      };
      env.TERM = "xterm-256color";
      colors = {
        primary = {
          background = "#${config.colorScheme.palette.base00}";
          foreground = "#${config.colorScheme.palette.base05}";
          dim_foreground = "#${config.colorScheme.palette.base05}";
          bright_foreground = "#${config.colorScheme.palette.base05}";
        };
        cursor = {
          text = "#${config.colorScheme.palette.base00}";
          cursor = "#${config.colorScheme.palette.base06}";
        };
        vi_mode_cursor = {
          text = "#${config.colorScheme.palette.base00}";
          cursor = "#${config.colorScheme.palette.base07}";
        };
        search = {
          matches = {
            foreground = "#${config.colorScheme.palette.base00}";
            background = "#${config.colorScheme.palette.base05}";
          };
          focused_match = {
            foreground = "#${config.colorScheme.palette.base00}";
            background = "#${config.colorScheme.palette.base0B}";
          };
        };
        footer_bar = {
          foreground = "#${config.colorScheme.palette.base00}";
          background = "#${config.colorScheme.palette.base05}";
        };
        hints = {
          start = {
            foreground = "#${config.colorScheme.palette.base00}";
            background = "#${config.colorScheme.palette.base0A}";
          };
          end = {
            foreground = "#${config.colorScheme.palette.base00}";
            background = "#${config.colorScheme.palette.base05}";
          };
        };
        selection = {
          text = "#${config.colorScheme.palette.base00}";
          background = "#${config.colorScheme.palette.base06}";
        };
        normal = {
          black = "#${config.colorScheme.palette.base03}";
          red = "#${config.colorScheme.palette.base08}";
          green = "#${config.colorScheme.palette.base0B}";
          yellow = "#${config.colorScheme.palette.base0A}";
          blue = "#${config.colorScheme.palette.base0D}";
          magenta = "#${config.colorScheme.palette.base0F}";
          cyan = "#${config.colorScheme.palette.base0C}";
          white = "#${config.colorScheme.palette.base05}";
        };
        bright = {
          black = "#${config.colorScheme.palette.base04}";
          red = "#${config.colorScheme.palette.base08}";
          green = "#${config.colorScheme.palette.base0B}";
          yellow = "#${config.colorScheme.palette.base0A}";
          blue = "#${config.colorScheme.palette.base0D}";
          magenta = "#${config.colorScheme.palette.base0F}";
          cyan = "#${config.colorScheme.palette.base0C}";
          white = "#${config.colorScheme.palette.base05}";
        };
        dim = {
          black = "#${config.colorScheme.palette.base03}";
          red = "#${config.colorScheme.palette.base08}";
          green = "#${config.colorScheme.palette.base0B}";
          yellow = "#${config.colorScheme.palette.base0A}";
          blue = "#${config.colorScheme.palette.base0D}";
          magenta = "#${config.colorScheme.palette.base0F}";
          cyan = "#${config.colorScheme.palette.base0C}";
          white = "#${config.colorScheme.palette.base05}";
        };
        indexed_colors = [
          { index = 16; color = "#${config.colorScheme.palette.base09}"; }
          { index = 17; color = "#${config.colorScheme.palette.base06}"; }
        ];
      };
    };
  };
}
