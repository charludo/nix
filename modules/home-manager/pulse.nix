{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop.pulse;
in
{
  options.desktop.pulse.enable = lib.mkEnableOption "enable pulse-related things";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [ pavucontrol ];
  };
}
