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
  # colorscheme = lib.mkDefault colorSchemes.tokyo-city-terminal-dark;

  # Use this method for custom imported schemes:
  colorscheme = lib.mkDefault customSchemes.gruvchad;

  background = builtins.toString ./common/desktop/backgrounds/wolf.png;
  #  -------
  # | eDP-1 |
  #  -------
  monitors = [{
    name = "eDP-1";
    width = 1920;
    height = 1080;
    x = 0;
    y = 0;
    workspace = "1";
    primary = true;
  }];

  # Configure waybar for this devices monitor setup
  programs.waybar.settings = {
    primary = {
      margin = "-10px 0px 10px 0px";
      layer = "top";
      position = "bottom";
      modules-left = [
        "custom/power"
        "clock"
        "custom/weather"
        "pulseaudio/slider"
        "custom/playerctl"
      ];
      modules-center = [ "hyprland/workspaces" ];
      modules-right = [
        "bluetooth"
        "custom/wireguard"
        "network#laptop"
        "disk#home"
        "cpu"
        "memory"
        "temperature"
        "battery"
        "custom/mail"
        "custom/reddit"
        "custom/updates"
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
      };
    } // customWaybarModules;
  };

  # Projects to manage on this machine
  projects = inputs.private-settings.projects;

}
