{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixvim.languages.godot;
in
{
  options.nixvim.languages.godot.enable = lib.mkEnableOption "Language config for godot";

  config = lib.mkIf cfg.enable {
    programs.nixvim.plugins.lsp.servers.gdscript.enable = true;
    programs.nixvim.plugins.lsp.servers.gdscript.package = pkgs.gdtoolkit_4;
    programs.nixvim.keymaps = [
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
    programs.nixvim.extraConfigLua = # lua
      ''
        require'lspconfig'.gdscript.setup{capabilities = require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities())}
      '';
    programs.nixvim.plugins.lint.lintersByFt.gdscript = [ "gdlint" ];
    programs.nixvim.plugins.conform-nvim.settings.formatters_by_ft.gdscript = [ "gdformat" ];
  };
}
