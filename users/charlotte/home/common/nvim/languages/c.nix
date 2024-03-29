{
  programs.nixvim.plugins.lsp.servers.clangd.enable = true;
  programs.nixvim.plugins.none-ls.sources = {
    formatting.clang_format.enable = true;
  };
}
