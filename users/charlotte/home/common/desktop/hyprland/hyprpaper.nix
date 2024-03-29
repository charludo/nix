{ inputs, config, ... }:
{
  imports = [ inputs.hyprpaper.homeManagerModules.default ];
  services.hyprpaper = {
    enable = true;
    preloads = [ config.background ];
    wallpapers = [ ",${config.background}" ];
    splash = false;
    ipc = false;
  };
}
