{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop.bitwig;
in
{
  options.desktop.bitwig = {
    enable = lib.mkEnableOption "Bitwig Studio";
    dataDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "path to an alternative data dir. Defaults to `~/Bitwig Studio`";
      default = null;
    };
  };

  config = lib.mkIf cfg.enable {

    home.packages = with pkgs; [
      bitwig-studio
    ];

    # Annoying hacks to make Bitwig use a different location for storage
    home.file."Bitwig Studio".source = lib.mkIf (cfg.dataDir != null) (
      config.lib.file.mkOutOfStoreSymlink cfg.dataDir
    );
    home.file.".hidden".text = ''
      Bitwig Studio
    '';

    # Bitwig otherwise looses focus when turning nobs/sliders under hyprland
    # https://github.com/hyprwm/Hyprland/issues/2034#issuecomment-1650278502
    wayland.windowManager.hyprland.settings.windowrulev2 = [
      "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"
    ];
  };
}
