{ inputs, config, lib, ... }:
let
  configuredMonitors = lib.filter (m: m.enabled && m.wallpaper != null) config.monitors;
in
{
  imports = [ inputs.hyprpaper.homeManagerModules.default ];
  services.hyprpaper = {
    enable = true;
    preloads = map (m: m.wallpaper) configuredMonitors ++ [ config.defaultWallpaper ];
    wallpapers = map (m: "${m.name},${m.wallpaper}") configuredMonitors ++ [ ",${config.defaultWallpaper}" ];
    splash = false;
    ipc = false;
  };
}
