{
  programs.nixvim.plugins.lsp.servers.ltex.enable = true;
  programs.nixvim.plugins.none-ls.sources = { };
  programs.nixvim.plugins.vimtex = {
    enable = true;
    settings = {
      view_method = "sioyek";
    };
  };
  programs.nixvim.opts.conceallevel = 2;
}
