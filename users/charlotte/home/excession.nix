{ inputs, lib, pkgs, config, ... }:
let
  customWaybarModules = import ./common/desktop/hyprland/waybar/modules.nix { inherit pkgs config inputs; };
  inherit (inputs.nix-colors) colorschemes;
  customSchemes = import ./common/desktop/common/customColorSchemes.nix;
in
{
  imports = [
    ./common
    ./common/games
    ./common/nvim
    ./common/desktop/hyprland
    ./common/cli/bitwarden.nix
    ./common/cli/direnv.nix
    ./common/cli/fish.nix
    ./common/cli/git.nix
    ./common/cli/ssh.nix
    ./common/desktop/common/alacritty.nix
    ./common/desktop/common/discord.nix
    ./common/desktop/common/easyeffects.nix
    ./common/desktop/common/element.nix
    ./common/desktop/common/firefox.nix
    ./common/desktop/common/gtk.nix
    ./common/desktop/common/jellyfin.nix
    ./common/desktop/common/mpv.nix
    ./common/desktop/common/nemo.nix
    ./common/desktop/common/playerctl.nix
    ./common/desktop/common/qt.nix
    ./common/desktop/common/theming.nix
    ./common/desktop/common/xdg.nix
  ];

  home.packages = with pkgs; [ telegram-desktop ];

  colorscheme = lib.mkDefault colorschemes.primer-dark-dimmed;
  defaultWallpaper = builtins.toString ./common/desktop/backgrounds/eso.png;
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
    }
    {
      name = "DP-3";
      width = 2560;
      height = 1440;
      x = 0;
      y = 1440;
      workspaces = [ "2" "4" "6" "8" "10" ];
      primary = true;
    }
  ];

  wayland.windowManager.hyprland.settings = {
    exec = [
      "steam -bigpicture"
      "firefox"
      "webcord"
      "jellyfinmediaplayer"
    ];

    windowrulev2 = [
      "opaque, class:(steam)$"
      "workspace 2, class:(steam),title:()"
      "workspace 1 silent, class:(firefox),title:()"
      "workspace 3 silent, class:(WebCord),title:()"
      "workspace 3 silent, class:(com.github.iwalton3.jellyfin-media-player),title:()"
      "fullscreenstate 0, class:(com.github.iwalton3.jellyfin-media-player),title:()"
    ];
  };

  # Configure waybar for this devices monitor setup
  programs.waybar.settings = {
    top = {
      margin = "15px 0px -5px 0px";
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
      output = [ "DP-2" ];
      modules-left = [
        "bluetooth"
        "network#lan"
        "network#wifi"
      ];
      modules-center = [ "hyprland/workspaces" ];
      modules-right = [
        "pulseaudio/slider"
        "custom/playerctl"
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
        };
      };
    } // customWaybarModules;
  };

  # Projects to manage on this machine
  projects = [{ name = "nix"; repo = "git@github.com:charludo/nix"; enableDirenv = false; }];

  # XDG dirs are (partly) symlinks to an external drive
  xdg.userDirs.extraConfig.XDG_CREATIVITY_DIR = "${config.home.homeDirectory}/Creativity";
  home.file = {
    "${config.xdg.userDirs.extraConfig.XDG_CREATIVITY_DIR}".source = config.lib.file.mkOutOfStoreSymlink "/media/Media/Kreatives";
    "${config.xdg.userDirs.documents}".source = config.lib.file.mkOutOfStoreSymlink "/media/Media/Dokumente";
    "${config.xdg.userDirs.music}".source = config.lib.file.mkOutOfStoreSymlink "/media/Media/Musik";
    "${config.xdg.userDirs.pictures}".source = config.lib.file.mkOutOfStoreSymlink "/media/Media/Fotos";
    "${config.xdg.userDirs.videos}".source = config.lib.file.mkOutOfStoreSymlink "/media/Media/Videos";
  };

  # Otherwise way too big on hub
  programs.alacritty.settings.font.size = lib.mkForce 13;
}
