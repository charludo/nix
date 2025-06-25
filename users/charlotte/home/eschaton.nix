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

  home.packages = with pkgs; [
    zoom-us
    teams-for-linux
  ];
  k9s.enable = true;

  home.hostname = "eschaton";

  # Use this method for built-in schemes:
  colorScheme = lib.mkDefault colorSchemes.primer-dark-dimmed;

  # Use this method for custom imported schemes:
  # colorScheme = lib.mkDefault customSchemes.gruvchad;

  # All colorSchemes from here can be set: https://tinted-theming.github.io/base16-gallery/
  # current favorites (apart from gruvchad): primer-dark-dimmed, tokyo-city-terminal-dark

  defaultWallpaper = ./common/desktop/backgrounds/river.png;
  #  -------
  # | eDP-1 |
  #  -------
  monitors = [
    {
      name = "eDP-1";
      width = 2880;
      height = 1800;
      x = 0;
      y = 0;
      scaling = 1.5;
      primary = true;
    }
  ];

  # Configure waybar for this devices monitor setup
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
        "network#eschaton"
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
    } // customWaybarModules;
  };

  # Projects to manage on this machine
  projects = private-settings.projects;

  nixvim.enable = true;
  nixvim.languages = {
    go.enable = true;
    python.enable = true;
    rust.enable = true;
    webdev.enable = true;
  };

  programs.fish.interactiveShellInit = # fish
    ''
      set -gx AGENIX_REKEY_PRIMARY_IDENTITY "${builtins.readFile ../perostek_age.pub}"
      set -gx AGENIX_REKEY_PRIMARY_IDENTITY_ONLY true
    '';

  accounts.email.accounts = private-settings.accountsWork;

  age.secrets.netrc.rekeyFile = secrets.charlotte-netrc;
  netrc.file = config.age.secrets.netrc.path;
}
