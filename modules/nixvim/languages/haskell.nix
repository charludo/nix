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
    lsp.servers.hls.enable = true;
    extraPackages = [ pkgs.ghc ];
  };
}
