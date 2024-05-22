{ config, lib, ... }:
let
  configuredMonitors = lib.filter (m: m.enabled && m.wallpaper != null) config.monitors;
in
{
  services.hyprpaper = {
    enable = true;
    settings = {
      preload = map (m: m.wallpaper) configuredMonitors ++ [ config.defaultWallpaper ];
      wallpaper = map (m: "${m.name},${m.wallpaper}") configuredMonitors ++ [ ",${config.defaultWallpaper}" ];
      splash = false;
      ipc = "off";
    };
  };
}
