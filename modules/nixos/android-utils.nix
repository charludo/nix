{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.androidUtils;
in
{
  options.androidUtils = {
    enable = lib.mkEnableOption "android utilities like adb, debloater,...";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.android-tools
      pkgs.universal-android-debloater
    ];
  };
}
