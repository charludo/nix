{ config, lib, ... }:
let
  cfg = config.cli.fzf;
in
{
  options.cli.fzf.enable = lib.mkEnableOption "fzf fuzzy file finder";

  config = lib.mkIf cfg.enable {
    programs.fzf = {
      enable = true;
      defaultOptions = [ "--color 16" ];
    };
  };
}
