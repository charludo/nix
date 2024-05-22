{ pkgs, ... }:
{
  imports = [
    ./alacritty.nix
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
    shotwell

    mattermost-desktop
    telegram-desktop

    orca-slicer
    musescore
  ];
}
