{ pkgs, ... }:
{
  programs.nixvim.plugins.lsp.servers.pylsp = {
    enable = true;
    filetypes = [ "python" ];
    settings.plugins = {
      black.enabled = true;
      black.line_length = 90;

      isort.enabled = true;
      pylint.enabled = true;

      pycodestyle.enabled = true;
      pycodestyle.maxLineLength = 90;
      pycodestyle.ignore = [ "E501" "W503" "R0903" ];
    };
  };
  programs.nixvim.plugins.lint.lintersByFt.python = [ "pylint" ];
  programs.nixvim.extraPackages = [ pkgs.pylint ];
}
