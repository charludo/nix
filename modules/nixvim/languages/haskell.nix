{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.nixvim.languages.haskell;
in
{
  options.nixvim.languages.haskell.enable = lib.mkEnableOption "Language config for haskell";

  config = lib.mkIf cfg.enable {
    programs.nixvim.plugins.lsp.servers.hls.enable = true;
    programs.nixvim.plugins.lsp.servers.hls.installGhc = true;
    programs.nixvim.extraPackages = [ pkgs.ghc ];
  };
}
