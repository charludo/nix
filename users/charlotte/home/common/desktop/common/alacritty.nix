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
          background = "#${config.colorscheme.palette.base00}";
          foreground = "#${config.colorscheme.palette.base05}";
          dim_foreground = "#${config.colorscheme.palette.base05}";
          bright_foreground = "#${config.colorscheme.palette.base05}";
        };
        cursor = {
          text = "#${config.colorscheme.palette.base00}";
          cursor = "#${config.colorscheme.palette.base06}";
        };
        vi_mode_cursor = {
          text = "#${config.colorscheme.palette.base00}";
          cursor = "#${config.colorscheme.palette.base07}";
        };
        search = {
          matches = {
            foreground = "#${config.colorscheme.palette.base00}";
            background = "#${config.colorscheme.palette.base05}";
          };
          focused_match = {
            foreground = "#${config.colorscheme.palette.base00}";
            background = "#${config.colorscheme.palette.base0B}";
          };
        };
        footer_bar = {
          foreground = "#${config.colorscheme.palette.base00}";
          background = "#${config.colorscheme.palette.base05}";
        };
        hints = {
          start = {
            foreground = "#${config.colorscheme.palette.base00}";
            background = "#${config.colorscheme.palette.base0A}";
          };
          end = {
            foreground = "#${config.colorscheme.palette.base00}";
            background = "#${config.colorscheme.palette.base05}";
          };
        };
        selection = {
          text = "#${config.colorscheme.palette.base00}";
          background = "#${config.colorscheme.palette.base06}";
        };
        normal = {
          black = "#${config.colorscheme.palette.base03}";
          red = "#${config.colorscheme.palette.base08}";
          green = "#${config.colorscheme.palette.base0B}";
          yellow = "#${config.colorscheme.palette.base0A}";
          blue = "#${config.colorscheme.palette.base0D}";
          magenta = "#${config.colorscheme.palette.base0F}";
          cyan = "#${config.colorscheme.palette.base0C}";
          white = "#${config.colorscheme.palette.base05}";
        };
        bright = {
          black = "#${config.colorscheme.palette.base04}";
          red = "#${config.colorscheme.palette.base08}";
          green = "#${config.colorscheme.palette.base0B}";
          yellow = "#${config.colorscheme.palette.base0A}";
          blue = "#${config.colorscheme.palette.base0D}";
          magenta = "#${config.colorscheme.palette.base0F}";
          cyan = "#${config.colorscheme.palette.base0C}";
          white = "#${config.colorscheme.palette.base05}";
        };
        dim = {
          black = "#${config.colorscheme.palette.base03}";
          red = "#${config.colorscheme.palette.base08}";
          green = "#${config.colorscheme.palette.base0B}";
          yellow = "#${config.colorscheme.palette.base0A}";
          blue = "#${config.colorscheme.palette.base0D}";
          magenta = "#${config.colorscheme.palette.base0F}";
          cyan = "#${config.colorscheme.palette.base0C}";
          white = "#${config.colorscheme.palette.base05}";
        };
        indexed_colors = [
          { index = 16; color = "#${config.colorscheme.palette.base09}"; }
          { index = 17; color = "#${config.colorscheme.palette.base06}"; }
        ];
      };
    };
  };
}
