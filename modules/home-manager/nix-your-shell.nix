{ config, lib, ... }:
let
  cfg = config.cli.nix-your-shell;
in
{
  options.cli.nix-your-shell.enable = lib.mkEnableOption "enable nix-your-shell";

  config = lib.mkIf cfg.enable {
    programs.nix-your-shell = {
      enable = true;
      enableFishIntegration = true;
    };
  };
}
