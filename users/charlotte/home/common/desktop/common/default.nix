{ pkgs, ... }:
{
  imports = [
    ./alacritty.nix
    ./darktable.nix
    ./daw.nix
    ./discord.nix
    ./easyeffects.nix
    ./element.nix
    ./firefox.nix
    ./gtk.nix
    ./jellyfin.nix
    ./mpv.nix
    ./musescore.nix
    ./nemo.nix
    ./pavucontrol.nix
    ./pdfpc.nix
    ./playerctl.nix
    ./qt.nix
    ./sioyek.nix
    ./theming.nix
    ./thunderbird.nix
    ./xdg.nix
  ];

  # Extra packages to always install for charlotte's desktops
  home.packages = with pkgs; [
    shotwell

    mattermost-desktop
    telegram-desktop
    jitsi-meet-electron

    orca-slicer
  ];
}
