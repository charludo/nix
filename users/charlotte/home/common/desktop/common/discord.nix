{ pkgs, ... }:
{
  home.packages = with pkgs; [
    webcord
  ];
  home.file.".config/discord/settings.json" = {
    text = ''
      {
      "SKIP_HOST_UPDATE": true
      }
    '';
  };
  # home.shellAliases.discord = "env XDG_SESSION_TYPE=x11 discord";
  xdg.desktopEntries.discord = {
    name = "Discord";
    type = "Application";
    terminal = false;
    exec = "webcord";
    categories = [
      "Network"
      "InstantMessaging"
    ];
    icon = "discord";
  };
}
