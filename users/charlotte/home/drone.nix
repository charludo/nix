{ private-settings, ... }:
{
  imports = [
    ./common
    ./common/cli.nix
    ./common/desktop.nix
  ];
  home.hostname = "drone";
  agenix-rekey.pubkey = ../keys/perostek_age.pub;

  desktop = {
    daw.enable = true;
    musescore.enable = true;
    pdfpc.enable = true;
  };
  cli.rmpc.enable = true;

  projects = private-settings.projects;
  nixvim.languages = {
    python.enable = true;
    rust.enable = true;
    webdev.enable = true;
  };

  #  -------
  # | eDP-1 |
  #  -------
  monitors = [
    {
      name = "eDP-1";
      width = 1920;
      height = 1080;
      x = 0;
      y = 0;
      primary = true;
    }
  ];
  defaultWallpaper = ./backgrounds/team-avatar.png;

  programs.waybar.settings = {
    primary = {
      margin = "-10px 0px 10px 0px";
      layer = "top";
      position = "bottom";
      modules-left = [
        "custom/power"
        "clock"
        "custom/calendar"
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
      };
    };
  };
}
