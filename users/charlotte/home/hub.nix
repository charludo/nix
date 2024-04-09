{ inputs, lib, pkgs, config, ... }:
let
  customWaybarModules = import ./common/desktop/hyprland/waybar/modules.nix { inherit pkgs config; };
  inherit (inputs.nix-colors) colorSchemes;
  customSchemes = import ./common/desktop/common/customColorSchemes.nix;
in
{
  imports = [
    ./common
    ./common/cli
    ./common/nvim
    ./common/desktop/common
    ./common/desktop/hyprland
  ];

  # Use this method for built-in schemes:
  colorscheme = lib.mkDefault colorSchemes.primer-dark-dimmed;

  # Use this method for custom imported schemes:
  # colorscheme = lib.mkDefault customSchemes.gruvchad;

  # All colorschemes from here can be set: https://tinted-theming.github.io/base16-gallery/
  # current favorites (apart from gruvchad): primer-dark-dimmed, tokyo-city-terminal-dark

  defaultWallpaper = builtins.toString ./common/desktop/backgrounds/wolf.png;
  #  ------
  # | DP-2 |
  #  ------
  #  ------
  # | DP-3 |
  #  ------
  monitors = [
    {
      name = "DP-2";
      width = 2560;
      height = 1440;
      x = 0;
      y = 0;
      workspaces = [ "1" "3" "5" "7" "9" ];
      primary = true;
    }
    {
      name = "DP-3";
      width = 2560;
      height = 1440;
      x = 0;
      y = 1440;
      workspaces = [ "2" "4" "6" "8" "10" ];
      # wallpaper = builtins.toString ./common/desktop/backgrounds/river.png;
    }
  ];

  # Configure waybar for this devices monitor setup
  programs.waybar.settings = {
    top = {
      margin = "-15px 0px -5px 0px";
      layer = "top";
      position = "top";
      output = [ "DP-2" ];
      modules-left = [
        "clock"
        "custom/weather"
      ];
      modules-center = [ "hyprland/workspaces" ];
      modules-right = [
        "disk#home"
        "disk#nas"
        "cpu"
        "memory"
        "temperature"
        "battery"
        "custom/power"
      ];
      "hyprland/workspaces" = {
        warp-on-scroll = false;
        all-outputs = false;
        format = "{icon}";
        format-icons = {
          default = "";
          urgent = "";
          active = "";
        };
        persistent-workspaces = {
          "1" = [ "DP-2" ];
          "3" = [ "DP-2" ];
          "5" = [ "DP-2" ];
          "7" = [ "DP-2" ];
          "9" = [ "DP-2" ];
        };
      };
    } // customWaybarModules;

    bottom = {
      margin = "-5px 0px -15px 0px";
      layer = "top";
      position = "bottom";
      output = [ "DP-3" ];
      modules-left = [
        "bluetooth"
        "network#lan"
        "network#wifi"
        "custom/wireguard"
      ];
      modules-center = [ "hyprland/workspaces" ];
      modules-right = [
        "pulseaudio/slider"
        "custom/playerctl"
        "custom/mail"
        "custom/reddit"
        "tray"
      ];
      "hyprland/workspaces" = {
        warp-on-scroll = false;
        all-outputs = false;
        format = "{icon}";
        format-icons = {
          default = "";
          urgent = "";
          active = "";
        };
        persistent-workspaces = {
          "2" = [ "DP-3" ];
          "4" = [ "DP-3" ];
          "6" = [ "DP-3" ];
          "8" = [ "DP-3" ];
          "10" = [ "DP-3" ];
        };
      };
    } // customWaybarModules;
  };

  # Projects to manage on this machine
  projects = inputs.private-settings.projects;
}
