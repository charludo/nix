{ pkgs, ... }:
{
  programs.nixvim.extraPlugins = [
    (pkgs.vimUtils.buildVimPlugin {
      name = "nvim-window-picker";
      src = pkgs.fetchFromGitHub {
        owner = "charludo";
        repo = "projectmgr.nvim";
        rev = "2d29b21b5afefa7a1690854c56db9b43195d9a10";
        sha256 = "/H3rX8EjwCEM4/mtvzLqa0+LzMYTnE+il7R639/BJx4=";
      };
    })
  ];

  programs.nixvim.keymaps = [
    { mode = [ "n" ]; key = "<leader>p"; action = "<cmd>Project<CR>"; options = { desc = "open projectmgr"; }; }
  ];
}
