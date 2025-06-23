{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.languages.latex;

  tex = (
    pkgs.texlive.combine {
      inherit (pkgs.texlive)
        scheme-full
        supertabular
        csquotes
        textpos
        appendix
        inconsolata
        lstaddons
        pgfplots
        todonotes
        xetex
        ;
    }
  );
in
{
  options.languages.latex.enable = lib.mkEnableOption "Language config for latex";

  config = lib.mkIf cfg.enable {
    plugins.vimtex = {
      enable = true;
      texlivePackage = tex;
      settings = {
        compiler_method = "latexmk";
        view_method = "sioyek";
      };
    };
    opts.conceallevel = 2;

    plugins.lsp.servers.ltex.enable = true;
    plugins.conform-nvim.settings.formatters_by_ft = {
      bib = [ "latexindent" ];
      plaintex = [ "latexindent" ];
      tex = [ "latexindent" ];
      quarto = [ "latexindent" ];
      context = [ "latexindent" ];
    };
    extraPackages = [ tex ];
  };
}
