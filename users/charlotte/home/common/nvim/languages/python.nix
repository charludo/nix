{
  programs.nixvim.plugins.lsp.servers.pylsp = {
    enable = true;
    filetypes = [ "python" ];
    settings.plugins = {
      black.enabled = true;
      black.line_length = 100;

      isort.enabled = true;
      pylint.enabled = true;

      pycodestyle.enabled = true;
      pycodestyle.maxLineLength = 100;
      pycodestyle.ignore = [ "E501" "W503" "R0903" ];
    };
  };
  programs.nixvim.plugins.none-ls.sources = {
    diagnostics.pylint.enable = true;
    diagnostics.mypy.enable = true;
    formatting.black.enable = true;
  };
}
