{ config, ... }:
{
  services.dunst = {
    enable = true;
    iconTheme.package = config.iconsProfile.package;
    iconTheme.name = "${config.iconsProfile.name}";
    settings = {
      global = {
        frame_color = "#${config.colorscheme.palette.base0E}";
        separator_color = "frame";
        corner_radius = 10;
        font = "${config.fontProfiles.regular.family} 11";
        mouse_left_click = "do_action";
        mouse_middle_click = "close_current";
        origin = "bottom-right";
        offset = "20x20";
      };
      urgency_low = {
        background = "#${config.colorscheme.palette.base00}CC";
        foreground = "#${config.colorscheme.palette.base05}";
      };
      urgency_normal = {
        background = "#${config.colorscheme.palette.base00}CC";
        foreground = "#${config.colorscheme.palette.base05}";
      };
      urgency_critical = {
        background = "#${config.colorscheme.palette.base00}C";
        foreground = "#${config.colorscheme.palette.base05}";
        frame_color = "#${config.colorscheme.palette.base09}";
      };
    };
  };
}
