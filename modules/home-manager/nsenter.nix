{
  config,
  lib,
  pkgs,
  outputs,
  ...
}:

let
  cfg = config.nsenter;
in
{
  options.nsenter.enable = lib.mkEnableOption "Enable nsenter for remote kubernetes";

  config = lib.mkIf cfg.enable {
    home.packages = [ outputs.packages.${pkgs.system}.nsenter ];
  };
}
