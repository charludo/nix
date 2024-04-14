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

  programs.nixvim.extraPlugins = with pkgs.vimPlugins; [
    { plugin = rust-vim; }
    { plugin = crates-nvim; }
  ];

  programs.nixvim.keymaps = [
    { mode = "n"; key = "<leader>cu"; action = "<cmd>lua require('crates').upgrade_all_crates()<cr>"; options = { silent = true; desc = "Update all crates"; }; }
  ];
}
