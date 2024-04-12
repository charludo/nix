{ pkgs, ... }:
let
  tex = (pkgs.texlive.combine {
    inherit (pkgs.texlive) scheme-full
      supertabular csquotes textpos appendix inconsolata lstaddons pgfplots todonotes;
  });
in
{
  home.packages = [ tex ];
  programs.nixvim.plugins.lsp.servers.ltex.enable = true;
  programs.nixvim.plugins.none-ls.sources = { };
  programs.nixvim.plugins.vimtex = {
    enable = true;
    texlivePackage = tex;
    settings = {
      view_method = "sioyek";
    };
  };
  programs.nixvim.opts.conceallevel = 2;
}
