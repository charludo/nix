{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.languages.rust;
in
{
  options.languages.rust.enable = lib.mkEnableOption "Language config for rust";

  config = lib.mkIf cfg.enable {
    plugins.lsp.servers.rust_analyzer = {
      enable = true;
      installCargo = false;
      installRustc = false;
      settings.cargo.features = "all";
      settings.diagnostics.styleLints.enable = true;
      settings.completion.privateEditable.enable = true;
      settings.inlayHints.lifetimeElisionHints.enable = "skip_trivial";
      settings.check.command = "clippy";
    };

    plugins.conform-nvim.settings.formatters_by_ft.rust = [ "rustfmt" ];
    extraPackages = [
      pkgs.rustfmt
      pkgs.lldb_20
      pkgs.cargo-nextest
    ];

    plugins.crates.enable = true;
    plugins.neotest.adapters.rust.enable = true;

    keymaps = [
      {
        mode = "n";
        key = "<leader>cu";
        action = "<cmd>lua require('crates').upgrade_all_crates()<cr>";
        options = {
          silent = true;
          desc = "Update all crates";
        };
      }
    ];

    plugins.dap.configurations.rust = [
      {
        name = "Launch debugger";
        type = "lldb";
        request = "launch";
        program = {
          __raw = # lua
            "function() return vim.fn.input('Path of the executable: ', vim.fn.getcwd() .. '/', 'file') end ";
        };
        cwd = {
          __raw = # lua
            ''"''${workspaceFolder}" '';
        };
        stopOnEntry = false;
        runInTerminal = false;
        args = [ ];
      }
    ];

    plugins.dap.adapters.executables.lldb = {
      command = "${lib.getExe' pkgs.lldb_20 "lldb-vscode"}";
    };
  };
}
