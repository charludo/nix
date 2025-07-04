{ pkgs, ... }:
let
  ignoredWords = pkgs.writeText "ignored.txt" ''
    crate
  '';
in
{
  plugins.lint.enable = true;

  # Spellcheck with ignored words
  extraPackages = [ pkgs.codespell ];
  # plugins.lint.customLinters.codespell = {
  # cmd = "${pkgs.codespell}/bin/codespell";
  # args = [ "--ignore-words=${ignoredWords}" ];
  # };

  # Enable codespell for all filetypes: https://github.com/mfussenegger/nvim-lint/issues/355#issuecomment-1759203127
  extraConfigLua = ''
    local lint = require("lint")
    vim.api.nvim_create_autocmd({"BufWritePost", "BufEnter"}, {
      group = vim.api.nvim_create_augroup('lint', { clear = true }),
      callback = function()
        lint.try_lint()
        lint.try_lint("codespell", "--ignore-words=${ignoredWords}")
      end
    })
  '';
}
