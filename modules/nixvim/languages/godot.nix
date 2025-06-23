{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.languages.godot;
in
{
  options.languages.godot.enable = lib.mkEnableOption "Language config for godot";

  config = lib.mkIf cfg.enable {
    plugins.lsp.servers.gdscript.enable = true;
    plugins.lsp.servers.gdscript.package = pkgs.gdtoolkit_4;
    keymaps = [
      {
        mode = [ "n" ];
        key = "<leader>gr";
        action = "<cmd>GodotRun<cr>";
        options = {
          desc = "run Godot scene";
        };
      }
      {
        mode = [ "n" ];
        key = "<leader>gs";
        action = "<cmd>GodotRunCurrent<cr>";
        options = {
          desc = "run current Godot scene";
        };
      }
    ];
    extraConfigLua = # lua
      ''
        require'lspconfig'.gdscript.setup{capabilities = require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities())}
      '';
    plugins.lint.lintersByFt.gdscript = [ "gdlint" ];
    plugins.conform-nvim.settings.formatters_by_ft.gdscript = [ "gdformat" ];
  };
}
