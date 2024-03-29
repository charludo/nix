{ config, lib, ... }:
let
  colors = import ../colors.nix { inherit config lib; };
in
{
  programs.nixvim.plugins.bufferline = {
    enable = true;
    alwaysShowBufferline = true;
    showTabIndicators = false;
    highlights =
      {
        background = { fg = colors.light_grey; bg = colors.black2; };
        indicatorVisible = { fg = colors.black2; bg = colors.black2; };
        bufferSelected = { fg = colors.white; bg = colors.black; italic = false; bold = false; };
        bufferVisible = { fg = colors.light_grey; bg = colors.black2; };
        offsetSeparator = { fg = colors.light_grey; bg = colors.black; };

        error = { fg = colors.light_grey; bg = colors.black2; };
        errorDiagnostic = { fg = colors.light_grey; bg = colors.black2; };

        closeButton = { fg = colors.light_grey; bg = colors.black2; };
        closeButtonVisible = { fg = colors.light_grey; bg = colors.black2; };
        closeButtonSelected = { fg = colors.red; bg = colors.black; };
        fill = { fg = colors.grey_fg; bg = colors.black2; };
        indicatorSelected = { fg = colors.black; bg = colors.black; };

        modified = { fg = colors.red; bg = colors.black2; };
        modifiedVisible = { fg = colors.red; bg = colors.black2; };
        modifiedSelected = { fg = colors.green; bg = colors.black; };

        separator = { fg = colors.black2; bg = colors.black2; };
        separatorVisible = { fg = colors.black2; bg = colors.black2; };
        separatorSelected = { fg = colors.black2; bg = colors.black2; };

        tab = { fg = colors.light_grey; bg = colors.one_bg3; };
        tabSelected = { fg = colors.black2; bg = colors.nord_blue; };
        tabClose = { fg = colors.red; bg = colors.black; };

        duplicate = { fg = "NONE"; bg = colors.black2; };
        duplicateSelected = { fg = colors.red; bg = colors.black; };
        duplicateVisible = { fg = colors.blue; bg = colors.black2; };
      };
    indicator.style = null;
    indicator.icon = " ";
    offsets = [
      { filetype = "NvimTree"; padding = 1; highlight = "NvimTreeWinSeparator"; }
    ];
  };

  # Solves the issue of nvim-tree focusing after a buffer is deleted
  programs.nixvim.plugins.vim-bbye.enable = true;

  programs.nixvim.keymaps = [
    { mode = "n"; key = "<Tab>"; action = "<cmd>BufferLineCycleNext<cr>"; options = { desc = "Cycle to next buffer"; }; }
    { mode = "n"; key = "<S-Tab>"; action = "<cmd>BufferLineCyclePrev<cr>"; options = { desc = "Cycle to previous buffer"; }; }
    { mode = "n"; key = "<leader>b"; action = "<cmd>enew<cr>"; options = { desc = "Create new empty buffer"; }; }
    { mode = "n"; key = "<leader>x"; action = "<cmd>Bdelete<cr>"; options = { desc = "Delete (close) current buffer"; }; }
  ];
}
