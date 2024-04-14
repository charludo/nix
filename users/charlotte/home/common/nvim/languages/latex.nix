{ pkgs, ... }:
let
  tex = (pkgs.texlive.combine {
    inherit (pkgs.texlive) scheme-full
      supertabular csquotes textpos appendix inconsolata lstaddons pgfplots todonotes;
  });
in
{
  programs.nixvim.plugins.vimtex = {
    enable = true;
    texlivePackage = tex;
    settings = {
      view_method = "sioyek";
    };
  };
  programs.nixvim.opts.conceallevel = 2;

  programs.nixvim.plugins.lsp.servers.ltex.enable = true;
  programs.nixvim.plugins.conform-nvim.formattersByFt = {
    bib = [ "latexindent" ];
    plaintex = [ "latexindent" ];
    tex = [ "latexindent" ];
    quarto = [ "latexindent" ];
    context = [ "latexindent" ];
  };
  programs.nixvim.extraPackages = [ tex ];
}
