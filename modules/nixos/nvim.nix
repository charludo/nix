{ config, lib, ... }:

with lib;
let
  cfg = config.nvim;
in
{
  options.nvim = {
    enable = lib.mkEnableOption (lib.mdDoc "enable NeoVim and make default editor");
  };

  config = mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
    };
  };
}
