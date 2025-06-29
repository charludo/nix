{ config, lib, ... }:
let
  cfg = config.desktop.alacritty;
  inherit (config.colorScheme) palette;
in
{
  options.desktop.alacritty.enable = lib.mkEnableOption "enable alacritty terminal emulator";
  options.desktop.alacritty.fontSize = lib.mkOption {
    type = lib.types.int;
    default = 14;
    description = "terminal font size";
  };

  config = lib.mkIf cfg.enable {

    programs.alacritty = {
      enable = true;
      settings = {
        font = {
          size = cfg.fontSize;
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
            background = "#${palette.base00}";
            foreground = "#${palette.base05}";
            dim_foreground = "#${palette.base05}";
            bright_foreground = "#${palette.base05}";
          };
          cursor = {
            text = "#${palette.base00}";
            cursor = "#${palette.base06}";
          };
          vi_mode_cursor = {
            text = "#${palette.base00}";
            cursor = "#${palette.base07}";
          };
          search = {
            matches = {
              foreground = "#${palette.base00}";
              background = "#${palette.base05}";
            };
            focused_match = {
              foreground = "#${palette.base00}";
              background = "#${palette.base0B}";
            };
          };
          footer_bar = {
            foreground = "#${palette.base00}";
            background = "#${palette.base05}";
          };
          hints = {
            start = {
              foreground = "#${palette.base00}";
              background = "#${palette.base0A}";
            };
            end = {
              foreground = "#${palette.base00}";
              background = "#${palette.base05}";
            };
          };
          selection = {
            text = "#${palette.base00}";
            background = "#${palette.base06}";
          };
          normal = {
            black = "#${palette.base03}";
            red = "#${palette.base08}";
            green = "#${palette.base0B}";
            yellow = "#${palette.base0A}";
            blue = "#${palette.base0D}";
            magenta = "#${palette.base0F}";
            cyan = "#${palette.base0C}";
            white = "#${palette.base05}";
          };
          bright = {
            black = "#${palette.base04}";
            red = "#${palette.base08}";
            green = "#${palette.base0B}";
            yellow = "#${palette.base0A}";
            blue = "#${palette.base0D}";
            magenta = "#${palette.base0F}";
            cyan = "#${palette.base0C}";
            white = "#${palette.base05}";
          };
          dim = {
            black = "#${palette.base03}";
            red = "#${palette.base08}";
            green = "#${palette.base0B}";
            yellow = "#${palette.base0A}";
            blue = "#${palette.base0D}";
            magenta = "#${palette.base0F}";
            cyan = "#${palette.base0C}";
            white = "#${palette.base05}";
          };
          indexed_colors = [
            {
              index = 16;
              color = "#${palette.base09}";
            }
            {
              index = 17;
              color = "#${palette.base06}";
            }
          ];
        };
      };
    };
  };
}
