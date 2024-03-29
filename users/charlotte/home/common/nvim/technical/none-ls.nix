{
  programs.nixvim.plugins.none-ls = {
    enable = true;
    onAttach = /* lua */''
      function(client)
          if client.server_capabilities.documentFormattingProvider then
              vim.cmd("autocmd BufWritePre <buffer> lua vim.lsp.buf.format()")
          end
      end
    '';
  };
} 
