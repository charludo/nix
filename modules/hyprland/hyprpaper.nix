{ config, lib, ... }:
let
  configuredMonitors = lib.filter (m: m.enabled && m.wallpaper != null) config.monitors;
in
{
  services.hyprpaper = {
    enable = true;
    settings = {
      preload = map (m: m.wallpaper) configuredMonitors ++ [ "${config.defaultWallpaper}" ];
      wallpaper =
        map (m: {
          monitor = m.name;
          path = "${m.wallpaper}";
        }) configuredMonitors
        ++ [
          {
            monitor = "";
            path = "${config.defaultWallpaper}";
          }
        ];
      splash = false;
      ipc = "off";
    };
  };
}
