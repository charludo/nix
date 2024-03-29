{ config, ... }:
{
  programs.sioyek = {
    enable = true;
    config = {
      "background_color" = "#${config.colorScheme.palette.base00}";
      "text_highlight_color" = "#${config.colorScheme.palette.base0A}";
      "visual_mark_color" = "#${config.colorScheme.palette.base04}";

      "search_highlight_color" = "#${config.colorScheme.palette.base0A}";
      "link_highlight_color" = "#${config.colorScheme.palette.base0D}";
      "synctex_highlight_color" = "#${config.colorScheme.palette.base0B}";

      "highlight_color_a" = "#${config.colorScheme.palette.base0A}";
      "highlight_color_b" = "#${config.colorScheme.palette.base0B}";
      "highlight_color_c" = "#${config.colorScheme.palette.base0D}";
      "highlight_color_d" = "#${config.colorScheme.palette.base0F}";
      "highlight_color_e" = "#${config.colorScheme.palette.base0E}";
      "highlight_color_f" = "#${config.colorScheme.palette.base08}";
      "highlight_color_g" = "#${config.colorScheme.palette.base0A}";

      "custom_background_color" = "#${config.colorScheme.palette.base00}";
      "custom_text_color" = "#${config.colorScheme.palette.base05}";

      "ui_text_color" = "#${config.colorScheme.palette.base05}";
      "ui_background_color" = "#${config.colorScheme.palette.base02}";
      "ui_selected_text_color" = "#${config.colorScheme.palette.base05}";
      "ui_selected_background_color" = "#${config.colorScheme.palette.base04}";
    };
  };
}
