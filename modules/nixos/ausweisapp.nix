{ config, lib, ... }:

with lib;
let
  cfg = config.ausweisapp;
in
{
  options.ausweisapp = {
    enable = lib.mkEnableOption "usage of the German ausweisapp";
  };

  config = mkIf cfg.enable {
    programs.ausweisapp.enable = true;
    programs.ausweisapp.openFirewall = true;
  };
}
