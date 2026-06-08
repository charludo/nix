{ config, lib, ... }:
let
  cfg = config.languages.c;
in
{
  options.languages.c.enable = lib.mkEnableOption "Language config for C, C++";

  config = lib.mkIf cfg.enable {
    lsp.servers.clangd.enable = true;
  };
}
