{ config, lib, ... }:

with lib;
let
  cfg = config.androidUtils;
in
{
  options.androidUtils = {
    enable = lib.mkEnableOption (lib.mdDoc "enable android utilities like adb, debloater,...");
  };

  config = mkIf cfg.enable {
    programs.adb.enable = true;
    environment.systemPackages = [
      pkgs.universal-android-debloater
    ];
  };
}
