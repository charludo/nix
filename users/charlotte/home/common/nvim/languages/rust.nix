{ pkgs, ... }:
{
  programs.nixvim.plugins.lsp.servers.rust-analyzer = {
    enable = true;
    installCargo = false;
    installRustc = false;
    settings.cargo.features = "all";
    settings.diagnostics.styleLints.enable = true;
  };

  programs.nixvim.plugins.conform-nvim.settings.formatters_by_ft.rust = [ "rustfmt" ];
  programs.nixvim.extraPackages = [ pkgs.rustfmt pkgs.lldb_17 ];

  programs.nixvim.plugins.crates-nvim.enable = true;

  programs.nixvim.keymaps = [
    { mode = "n"; key = "<leader>cu"; action = "<cmd>lua require('crates').upgrade_all_crates()<cr>"; options = { silent = true; desc = "Update all crates"; }; }
  ];

  programs.nixvim.plugins.dap.configurations.rust = [{
    name = "Launch debugger";
    type = "lldb";
    request = "launch";
    program = { __raw = /* lua */ '' function() return vim.fn.input('Path of the executable: ', vim.fn.getcwd() .. '/', 'file') end ''; };
    cwd = { __raw = /* lua */ '' "''${workspaceFolder}" ''; };
    stopOnEntry = false;
    runInTerminal = false;
    args = [ ];
  }];

  programs.nixvim.plugins.dap.adapters.executables.lldb = {
    command = "${pkgs.lldb_17}/bin/lldb-vscode";
  };
}
