{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop.jellyfin;
in
{
  options.desktop.jellyfin.enable = lib.mkEnableOption "Jellyfin client";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      jellyfin-media-player
      mpd-mpris
      playerctl
    ];

    # Necessary so we can use playerctl to enquire about the player state (e.g. from a waybar module)
    home.file.".local/share/jellyfinmediaplayer/mpv.conf".text = ''
      input-ipc-server=/tmp/mpvsocket
    '';

    # Same reason...
    programs.mpv.enable = true;
    programs.mpv.scripts = [ pkgs.mpvScripts.mpris ];
    home.file.".local/share/jellyfinmediaplayer/scripts/mpris.so".source =
      "${pkgs.mpvScripts.mpris}/share/mpv/scripts/mpris.so";

    services.playerctld.enable = true;
  };
}
