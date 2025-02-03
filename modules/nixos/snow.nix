{
  inputs,
  lib,
  config,
  ...
}:
let
  cfg = config.snow;
in
{
  options.snow.enable = lib.mkEnableOption "install the snow nix manager";
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      inputs.snow.packages.x86_64-linux.default
    ];
  };
}
