{
  programs.nixvim.plugins.lsp.servers = {
    ccls.enable = true;
    html.enable = true;
    htmx.enable = true;
    eslint.enable = true;
    phpactor.enable = true;
  };
  programs.nixvim.plugins.none-ls.sources = {
    formatting.prettierd.enable = true;
    formatting.stylelint.enable = true;
    formatting.djlint.enable = true;
    formatting.djlint.withArgs = ''{ filetypes = { "jinja", "jinja.html", "twig", "htmldjango", "django", "html" } }'';
    diagnostics.djlint.enable = true;
  };
}
