{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nemo-with-extensions
    nemo-fileroller
  ];

  xdg.desktopEntries.nemo = {
    name = "Nemo";
    type = "Application";
    comment = "Access and organize files";
    terminal = false;
    exec = "nemo %U";
    categories = [ "Utility" "Core" ];
    icon = "system-file-manager";
    mimeType = [ "inode/directory" "application/x-gnome-saved-search" ];
    actions = {
      "open-home" = { name = "Home"; exec = "nemo %U"; };
      "open-computer" = { name = "Computer"; exec = "name computer:///"; };
      "open-trash" = { name = "Trash"; exec = "nemo trash:///"; };
    };
  };
}
