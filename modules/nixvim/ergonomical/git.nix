{ config, ... }:
{
  plugins = {
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

  keymaps = [
    {
      mode = [ "n" ];
      key = "<leader>gb";
      action = "<cmd>Gitsigns toggle_current_line_blame<cr>";
      options = {
        desc = "toggle current line blame";
      };
    }
  ];

  highlight = {
    diffOldFile = {
      fg = config.palette.baby_pink;
    };
    diffNewFile = {
      fg = config.palette.blue;
    };
    DiffAdd = {
      fg = config.palette.blue;
    };
    DiffAdded = {
      fg = config.palette.green;
    };
    DiffChange = {
      fg = config.palette.light_grey;
    };
    DiffChangeDelete = {
      fg = config.palette.red;
    };
    DiffModified = {
      fg = config.palette.orange;
    };
    DiffDelete = {
      fg = config.palette.red;
    };
    DiffRemoved = {
      fg = config.palette.red;
    };
    DiffText = {
      fg = config.palette.white;
      bg = config.palette.black2;
    };
    gitcommitOverflow = {
      fg = config.palette.base08;
    };
    gitcommitSummary = {
      fg = config.palette.base0B;
    };
    gitcommitComment = {
      fg = config.palette.base03;
    };
    gitcommitUntracked = {
      fg = config.palette.base03;
    };
    gitcommitDiscarded = {
      fg = config.palette.base03;
    };
    gitcommitSelected = {
      fg = config.palette.base03;
    };
    gitcommitHeader = {
      fg = config.palette.base0E;
    };
    gitcommitSelectedType = {
      fg = config.palette.base0D;
    };
    gitcommitUnmergedType = {
      fg = config.palette.base0D;
    };
    gitcommitDiscardedType = {
      fg = config.palette.base0D;
    };
    gitcommitBranch = {
      fg = config.palette.base09;
      bold = true;
    };
    gitcommitUntrackedFile = {
      fg = config.palette.base0A;
    };
    gitcommitUnmergedFile = {
      fg = config.palette.base08;
      bold = true;
    };
    gitcommitDiscardedFile = {
      fg = config.palette.base08;
      bold = true;
    };
    gitcommitSelectedFile = {
      fg = config.palette.base0B;
      bold = true;
    };
  };

}
