{
  programs.nixvim.plugins.lsp.servers.gdscript.enable = true;
  programs.nixvim.plugins.none-ls.sources = {
    formatting.gdformat.enable = true;
    diagnostics.gdlint.enable = true;
    diagnostics.gdlint.withArgs = ''{ filetypes = { "gd", "gdscript", "gdscript3" } }'';
  };
  programs.nixvim.keymaps = [
    { mode = [ "n" ]; key = "<leader>gr"; action = "<cmd>GodotRun<cr>"; options = { desc = "run Godot scene"; }; }
    { mode = [ "n" ]; key = "<leader>gs"; action = "<cmd>GodotRunCurrent<cr>"; options = { desc = "run current Godot scene"; }; }
  ];
  programs.nixvim.extraConfigLua = /* lua */ ''
    require'lspconfig'.gdscript.setup{capabilities = require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities())}
  '';
}
