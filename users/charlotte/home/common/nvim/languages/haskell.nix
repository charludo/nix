{ pkgs, ... }:
{
  programs.nixvim.plugins.lsp.servers.hls.enable = true;
  programs.nixvim.extraPackages = [ pkgs.ghc ];
}
