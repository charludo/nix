{
  pkgs,
  config,
  private-settings,
  ...
}:
{
  imports = [
    ./common
    ./common/cli.nix
    ./common/desktop.nix
  ];
  home.hostname = "hub";
  agenix-rekey.pubkey = ../keys/zakalwe_age.pub;

  desktop = {
    darktable.enable = true;
    discord.enable = true;
    musescore.enable = true;
    pdfpc.enable = true;
  };
  cli = {
    netrc.file = config.age.secrets.netrc.path;
    k9s.enable = true;
    rmpc.enable = true;
  };

  fontProfiles.monospace.size = 13;

  home.packages = with pkgs; [
    teams-for-linux
    mattermost-desktop

    anki-bin
    orca-slicer
    bitwig-studio

    ours.nsenter
  ];

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

  projects = private-settings.projects;
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
      primary = true;
    }
  ];
  defaultWallpaper = ./backgrounds/river.png;

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
    };

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
    };
  };
}
