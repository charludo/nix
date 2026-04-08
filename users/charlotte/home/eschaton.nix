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
  home.hostname = "eschaton";
  agenix-rekey.pubkey = ../keys/perostek_age.pub;

  cli = {
    netrc.file = config.age.secrets.netrc.path;
    k9s.enable = true;
    rmpc.enable = true;
  };
  desktop = {
    daw.enable = true;
    fcitx.enable = true;
    musescore.enable = true;
    pdfpc.enable = true;
  };

  home.packages = with pkgs; [
    anki
    teams-for-linux
    jitsi-meet-electron
    ours.nsenter

    (pkgs.writeShellApplication {
      name = "sway";
      runtimeInputs = [ pkgs.cowsay ];
      text = ''
        cowsay "we have sway at home"
      '';
    })
  ];

  accounts.email.accounts = private-settings.charlotte.accountsWork;

  projects = private-settings.projects;
  nixvim.languages = {
    go.enable = true;
    python.enable = true;
    rust.enable = true;
    webdev.enable = true;
  };

  services.ssh-agent = {
    enable = true;
    enableFishIntegration = true;
  };

  services.hypridle.settings.listener = [
    {
      timeout = 900;
      on-timeout = "hyprlock";
    }
  ];
  systemd.user.services.swayidle = {
    Service = {
      ExecStart = "swaylock";
      Type = "simple";
      Restart = "no";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

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
  defaultWallpaper = ./backgrounds/river.png;

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
    };
  };
}
