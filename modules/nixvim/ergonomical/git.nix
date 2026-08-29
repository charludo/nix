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
    git-worktree = {
      enable = true;
      enableTelescope = true;
    };
  };

  # Shorthand: prompt for a branch name only, and create the worktree at <main repo root>/.worktree/<branch>.
  extraConfigLua = ''
    function git_worktree_new()
      local common = vim.fn.systemlist({ "git", "rev-parse", "--path-format=absolute", "--git-common-dir" })[1]
      if vim.v.shell_error ~= 0 or not common or common == "" then
        vim.notify("git-worktree: not inside a git repository", vim.log.levels.ERROR)
        return
      end

      local root = common
      if vim.fn.fnamemodify(common, ":t") == ".git" then
        root = vim.fn.fnamemodify(common, ":h")
      end

      vim.ui.input({ prompt = "New worktree branch: " }, function(branch)
        if not branch or branch == "" then
          return
        end
        require("git-worktree").create_worktree(root .. "/.worktree/" .. branch, branch)
      end)
    end
  '';

  keymaps = [
    {
      mode = [ "n" ];
      key = "<leader>gb";
      action = "<cmd>Gitsigns toggle_current_line_blame<cr>";
      options = {
        desc = "toggle current line blame";
      };
    }
    {
      mode = [ "n" ];
      key = "<leader>gw";
      action = "<cmd>Telescope git_worktree git_worktree<cr>";
      options = {
        # in-picker: <cr> switch, <m-d> delete, <m-c> create, <c-f> toggle force
        desc = "Telescope Git worktrees";
      };
    }
    {
      mode = [ "n" ];
      key = "<leader>gW";
      action = "<cmd>Telescope git_worktree create_git_worktree<cr>";
      options = {
        desc = "Telescope Git worktree create (pick branch + path)";
      };
    }
    {
      mode = [ "n" ];
      key = "<leader>gn";
      action = "<cmd>lua git_worktree_new()<cr>";
      options = {
        desc = "Git worktree new (branch name only, into .worktree/)";
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
