{ config, ... }:
{
  programs.nixvim.plugins = {
    fugitive.enable = true;
    gitsigns = {
      enable = true;
      settings.signs = {
        add = {
          text = "│";
        };
        change = {
          text = "│";
        };
        delete = {
          text = "󰍵";
        };
        topdelete = {
          text = "‾";
        };
        changedelete = {
          text = "~";
        };
        untracked = {
          text = "│";
        };
      };
    };
  };

  programs.nixvim.keymaps = [
    {
      mode = [ "n" ];
      key = "<leader>gb";
      action = "<cmd>Gitsigns toggle_current_line_blame<cr>";
      options = {
        desc = "toggle current line blame";
      };
    }
  ];

  programs.nixvim.highlight = {
    diffOldFile = {
      fg = config.nixvim.palette.baby_pink;
    };
    diffNewFile = {
      fg = config.nixvim.palette.blue;
    };
    DiffAdd = {
      fg = config.nixvim.palette.blue;
    };
    DiffAdded = {
      fg = config.nixvim.palette.green;
    };
    DiffChange = {
      fg = config.nixvim.palette.light_grey;
    };
    DiffChangeDelete = {
      fg = config.nixvim.palette.red;
    };
    DiffModified = {
      fg = config.nixvim.palette.orange;
    };
    DiffDelete = {
      fg = config.nixvim.palette.red;
    };
    DiffRemoved = {
      fg = config.nixvim.palette.red;
    };
    DiffText = {
      fg = config.nixvim.palette.white;
      bg = config.nixvim.palette.black2;
    };
    gitcommitOverflow = {
      fg = config.nixvim.palette.base08;
    };
    gitcommitSummary = {
      fg = config.nixvim.palette.base0B;
    };
    gitcommitComment = {
      fg = config.nixvim.palette.base03;
    };
    gitcommitUntracked = {
      fg = config.nixvim.palette.base03;
    };
    gitcommitDiscarded = {
      fg = config.nixvim.palette.base03;
    };
    gitcommitSelected = {
      fg = config.nixvim.palette.base03;
    };
    gitcommitHeader = {
      fg = config.nixvim.palette.base0E;
    };
    gitcommitSelectedType = {
      fg = config.nixvim.palette.base0D;
    };
    gitcommitUnmergedType = {
      fg = config.nixvim.palette.base0D;
    };
    gitcommitDiscardedType = {
      fg = config.nixvim.palette.base0D;
    };
    gitcommitBranch = {
      fg = config.nixvim.palette.base09;
      bold = true;
    };
    gitcommitUntrackedFile = {
      fg = config.nixvim.palette.base0A;
    };
    gitcommitUnmergedFile = {
      fg = config.nixvim.palette.base08;
      bold = true;
    };
    gitcommitDiscardedFile = {
      fg = config.nixvim.palette.base08;
      bold = true;
    };
    gitcommitSelectedFile = {
      fg = config.nixvim.palette.base0B;
      bold = true;
    };
  };

}
