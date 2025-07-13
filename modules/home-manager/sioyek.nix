{ config, lib, ... }:
let
  cfg = config.desktop.sioyek;
  inherit (config.colorScheme) palette;
in
{
  options.desktop.sioyek.enable = lib.mkEnableOption "Sioyek PDF viewer";

  config = lib.mkIf cfg.enable {
    programs.sioyek = {
      enable = true;
      config = {
        "background_color" = "#${palette.base00}";
        "text_highlight_color" = "#${palette.base0A}";
        "visual_mark_color" = "#${palette.base04}";

        "search_highlight_color" = "#${palette.base0A}";
        "link_highlight_color" = "#${palette.base0D}";
        "synctex_highlight_color" = "#${palette.base0B}";

        "highlight_color_a" = "#${palette.base0A}";
        "highlight_color_b" = "#${palette.base0B}";
        "highlight_color_c" = "#${palette.base0D}";
        "highlight_color_d" = "#${palette.base0F}";
        "highlight_color_e" = "#${palette.base0E}";
        "highlight_color_f" = "#${palette.base08}";
        "highlight_color_g" = "#${palette.base0A}";

        "custom_background_color" = "#${palette.base00}";
        "custom_text_color" = "#${palette.base05}";

        "ui_text_color" = "#${palette.base05}";
        "ui_background_color" = "#${palette.base02}";
        "ui_selected_text_color" = "#${palette.base05}";
        "ui_selected_background_color" = "#${palette.base04}";
      };
    };
  };
}
