{ pkgs, ... }:
{
  programs.nixvim.plugins.lint.enable = true;
  programs.nixvim.plugins.lint.lintersByFt."*" = [ "codespell" ];
  programs.nixvim.extraPackages = [ pkgs.codespell ];
}
