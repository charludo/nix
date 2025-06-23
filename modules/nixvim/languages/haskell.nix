{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.languages.haskell;
in
{
  options.languages.haskell.enable = lib.mkEnableOption "Language config for haskell";

  config = lib.mkIf cfg.enable {
    plugins.lsp.servers.hls.enable = true;
    plugins.lsp.servers.hls.installGhc = true;
    extraPackages = [ pkgs.ghc ];
  };
}
