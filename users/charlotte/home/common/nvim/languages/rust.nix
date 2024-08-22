{ pkgs, ... }:
{
  programs.nixvim.plugins.lsp.servers.rust-analyzer = {
    enable = true;
    installCargo = false;
    installRustc = false;
    settings.cargo.features = "all";
    settings.diagnostics.styleLints.enable = true;
  };

  programs.nixvim.plugins.conform-nvim.formattersByFt.rust = [ "rustfmt" ];
  programs.nixvim.extraPackages = [ pkgs.rustfmt ];

  programs.nixvim.plugins.crates-nvim.enable = true;

  programs.nixvim.keymaps = [
    { mode = "n"; key = "<leader>cu"; action = "<cmd>lua require('crates').upgrade_all_crates()<cr>"; options = { silent = true; desc = "Update all crates"; }; }
  ];

  programs.nixvim.plugins.dap.configurations.rust = [{
    name = "Launch debugger";
    type = "lldb";
    request = "launch";
    cwd = ''''${workspaceFolder}'';
    program = "$\{file}";
  }];
  programs.nixvim.plugins.dap.adapters.executables.lldb.command = "rust-lldb";
}
