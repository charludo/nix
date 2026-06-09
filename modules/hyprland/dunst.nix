{ config, ... }:
{
  services.dunst = {
    enable = true;
    settings = {
      global = {
        frame_color = config.colors.palette.base0E;
        separator_color = "frame";
        corner_radius = 10;
        font = "${config.fontProfiles.regular.family} 11";
        mouse_left_click = "do_action";
        mouse_middle_click = "close_current";
        origin = "bottom-right";
        offset = "20x20";
        enable_recursive_icon_lookup = true;
        icon_theme = config.iconsProfile.name;
      };
      urgency_low = {
        background = "${config.colors.palette.base00}CC";
        foreground = config.colors.palette.base05;
      };
      urgency_normal = {
        background = "${config.colors.palette.base00}CC";
        foreground = config.colors.palette.base05;
      };
      urgency_critical = {
        background = "${config.colors.palette.base00}C";
        foreground = config.colors.palette.base05;
        frame_color = config.colors.palette.base09;
      };
    };
  };
}
