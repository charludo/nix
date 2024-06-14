{
  xdg.desktopEntries.steam = {
    name = "Steam";
    type = "Application";
    comment = "Application for managing and playing games on Steam";
    terminal = false;
    exec = "steam -bigpicture %U";
    categories = [ "Network" "Game" ];
    icon = "steam";
  };
}
