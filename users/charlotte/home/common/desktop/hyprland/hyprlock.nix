{ config, ... }:
let
  primaryMonitor = (builtins.head (builtins.filter (monitor: monitor.primary) config.monitors)).name;
in
{
  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        disable_loading_bar = true;
        hide_cursor = false;
        no_fade_in = false;
      };

      backgrounds = [
        {
          monitor = "";
          path = "${config.defaultWallpaper}";

          blur_passes = 1;
          blur_size = 7;
          noise = 0.0117;
          contrast = 0.8916;
          brightness = 0.8172;
          vibrancy = 0.1696;
          vibrancy_darkness = 0.0;
        }
      ];

      input-fields = [
        {
          monitor = "${primaryMonitor}";

          size = {
            width = 250;
            height = 45;
          };
          outline_thickness = 2;
          dots_size = 0.33;
          dots_spacing = 0.25;
          dots_center = true;
          outer_color = "rgb(0, 0, 0, 0.15)";
          inner_color = "rgb(0, 0, 0, 0)";
          check_color = "rgb(0, 0, 0, 0)";
          font_color = "#${config.colorScheme.palette.base09}";
          fade_on_empty = true;
          placeholder_text = "";
          hide_input = false;

          position = {
            x = 0;
            y = -30;
          };
          halign = "center";
          valign = "center";
        }
      ];

      labels = [
        {
          monitor = "${primaryMonitor}";
          text = "enter password for <span font_family=\"${config.fontProfiles.monospace.family}\">$USER</span>";
          color = "#${config.colorScheme.palette.base00}";
          font_size = 24;
          font_family = "${config.fontProfiles.regular.family}";
          position = {
            x = 0;
            y = 30;
          };

          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
