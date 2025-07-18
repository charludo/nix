{ config, lib, ... }:

with lib;
let
  cfg = config.docker;
in
{
  options.docker = {
    enable = lib.mkEnableOption "docker (ugh)";
  };

  config = mkIf cfg.enable {
    virtualisation.docker.enable = true;
    virtualisation.docker.rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };
}
