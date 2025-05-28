{ config, lib, ... }:
let
  cfg = config.nixvim.languages.c;
in
{
  options.nixvim.languages.c.enable = lib.mkEnableOption "Language config for C, C++";

  config = lib.mkIf cfg.enable {
    programs.nixvim.plugins.lsp.servers.clangd.enable = true;
  };
}
