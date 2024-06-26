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

      background = [
        {
          monitor = "";
          path = "${config.defaultWallpaper}";

          blur_passes = 2;
          blur_size = 5;
          noise = 0.0117;
          contrast = 0.8916;
          brightness = 0.8172;
          vibrancy = 0.1696;
          vibrancy_darkness = 0.0;
        }
      ];

      input-field = [
        {
          monitor = "${primaryMonitor}";
          size = "250, 45";
          outline_thickness = 2;
          dots_size = 0.33;
          dots_spacing = 0.25;
          dots_center = true;
          outer_color = "rgba(255, 255, 255, 0.15)";
          inner_color = "rgba(0, 0, 0, 0)";
          check_color = "rgba(0, 0, 0, 0)";
          font_color = "rgba(255, 255, 255, 0.8)";
          fade_on_empty = true;
          placeholder_text = "";
          hide_input = false;

          position = "0, -30";
          halign = "center";
          valign = "center";
        }
      ];

      label = [
        {
          monitor = "${primaryMonitor}";
          text = "enter password for <span font_family=\"${config.fontProfiles.monospace.family}\">$USER</span>";
          color = "rgba(255, 255, 255, 0.8)";
          font_size = 24;
          font_family = "${config.fontProfiles.regular.family}";

          position = "0, 30";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
