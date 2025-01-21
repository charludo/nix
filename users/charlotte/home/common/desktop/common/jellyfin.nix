{ pkgs, ... }:
{
  home.packages = [
    pkgs.jellyfin-media-player
    pkgs.mpd-mpris
  ];

  # Necessary so we can use playerctl to enquire about the player state (e.g. from a waybar module)
  home.file.".local/share/jellyfinmediaplayer/mpv.conf".text = ''
    input-ipc-server=/tmp/mpvsocket
  '';

  # Same reason...
  programs.mpv.scripts = [ pkgs.mpvScripts.mpris ];
  home.file.".local/share/jellyfinmediaplayer/scripts/mpris.so".source =
    "${pkgs.mpvScripts.mpris}/share/mpv/scripts/mpris.so";

}
