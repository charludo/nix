{
  inputs,
  lib,
  pkgs,
  config,
  private-settings,
  secrets,
  ...
}:
let
  customWaybarModules = import ./common/desktop/hyprland/waybar/modules.nix {
    inherit pkgs config private-settings;
  };
  inherit (inputs.nix-colors) colorSchemes;
  # deadnix: skip
  customSchemes = import ./common/desktop/common/customColorSchemes.nix;
in
{
  imports = [
    ./common
    ./common/cli
    ./common/desktop/common
    ./common/desktop/hyprland
  ];

  home.packages = with pkgs; [ teams-for-linux ];
  k9s.enable = true;

  home.hostname = "hub";

  # Use this method for built-in schemes:
  colorScheme = lib.mkDefault colorSchemes.primer-dark-dimmed;

  # Use this method for custom imported schemes:
  # colorScheme = lib.mkDefault customSchemes.gruvchad;

  # All colorSchemes from here can be set: https://tinted-theming.github.io/base16-gallery/
  # current favorites (apart from gruvchad): primer-dark-dimmed, tokyo-city-terminal-dark

  defaultWallpaper = ./common/desktop/backgrounds/river.png;
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
      workspaces = [
        "1"
        "3"
        "5"
        "7"
        "9"
      ];
    }
    {
      name = "DP-3";
      width = 2560;
      height = 1440;
      x = 0;
      y = 1440;
      workspaces = [
        "2"
        "4"
        "6"
        "8"
        "10"
      ];
      # wallpaper = builtins.toString ./common/desktop/backgrounds/river.png;
      primary = true;
    }
  ];

  # Configure waybar for this devices monitor setup
  programs.waybar.settings = {
    top = {
      margin = "15px 0px -5px 0px";
      layer = "top";
      position = "top";
      output = [ "DP-2" ];
      modules-left = [
        "clock"
        "custom/calendar"
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
          "1" = [ ];
          "3" = [ ];
          "5" = [ ];
          "7" = [ ];
          "9" = [ ];
        };
      };
    } // customWaybarModules;

    bottom = {
      margin = "-5px 0px 15px 0px";
      layer = "top";
      position = "bottom";
      output = [ "DP-3" ];
      modules-left = [
        "bluetooth"
        "network#lan"
        "network#wifi"
      ];
      modules-center = [ "hyprland/workspaces" ];
      modules-right = [
        "pulseaudio/slider"
        "custom/playerctl"
        "custom/mail"
        "custom/lemmy"
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
          "2" = [ ];
          "4" = [ ];
          "6" = [ ];
          "8" = [ ];
          "10" = [ ];
        };
      };
    } // customWaybarModules;
  };

  # Projects to manage on this machine
  projects = private-settings.projects;

  nixvim.enable = true;
  nixvim.languages = {
    c.enable = false;
    godot.enable = false;
    haskell.enable = false;
    latex.enable = false;

    go.enable = true;
    python.enable = true;
    rust.enable = true;
    webdev.enable = true;
  };

  # XDG dirs are (partly) symlinks to an external drive
  xdg.userDirs.extraConfig.XDG_CREATIVITY_DIR = "${config.home.homeDirectory}/Creativity";
  home.file = {
    "${config.xdg.userDirs.extraConfig.XDG_CREATIVITY_DIR}".source =
      config.lib.file.mkOutOfStoreSymlink "/media/Media/Kreatives";
    "${config.xdg.userDirs.documents}".source =
      config.lib.file.mkOutOfStoreSymlink "/media/Media/Dokumente";
    "${config.xdg.userDirs.music}".source = config.lib.file.mkOutOfStoreSymlink "/media/Media/Musik";
    "${config.xdg.userDirs.pictures}".source = config.lib.file.mkOutOfStoreSymlink "/media/Media/Fotos";
    "${config.xdg.userDirs.videos}".source = config.lib.file.mkOutOfStoreSymlink "/media/Media/Videos";
  };

  # Otherwise way to big on hub
  programs.alacritty.settings.font.size = lib.mkForce 13;

  programs.fish.interactiveShellInit = # fish
    ''
      set -gx AGENIX_REKEY_PRIMARY_IDENTITY "${builtins.readFile ../zakalwe_age.pub}"
      set -gx AGENIX_REKEY_PRIMARY_IDENTITY_ONLY true
    '';

  age.secrets.netrc.rekeyFile = secrets.charlotte-netrc;
  netrc.file = config.age.secrets.netrc.path;

  nsenter.enable = true;
}
