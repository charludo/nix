{ pkgs, ... }:
{
  imports = [
    ./alacritty.nix
    ./darktable.nix
    ./discord.nix
    ./easyeffects.nix
    ./firefox.nix
    ./gtk.nix
    ./jellyfin.nix
    ./mpv.nix
    ./pavucontrol.nix
    ./pdfpc.nix
    ./playerctl.nix
    ./qt.nix
    ./sioyek.nix
    ./themeing.nix
    ./thunderbird.nix
    ./xdg.nix
  ];

  # Extra packages to always install for charlotte's desktops
  home.packages = with pkgs; [
    cinnamon.nemo-with-extensions
    cinnamon.nemo-fileroller

    shotwell

    mattermost-desktop
    telegram-desktop

    orca-slicer
    musescore
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
