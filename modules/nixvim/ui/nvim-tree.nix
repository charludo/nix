{ config, ... }:
let
  colors = config.palette;
in
{
  plugins.nvim-tree = {
    enable = true;
    settings = {
      filters = {
        dotfiles = false;
      };
      disable_netrw = true;
      hijack_netrw = true;
      hijack_cursor = true;
      hijack_unnamed_buffer_when_opening = false;
      sync_root_with_cwd = true;
      update_focused_file = {
        enable = true;
        update_root = false;
      };
      view = {
        side = "left";
        width = 35;
        preserve_window_proportions = true;
      };
      git = {
        enable = true;
        ignore = true;
      };
      filesystem_watchers = {
        enable = true;
      };
      actions = {
        open_file = {
          resize_window = false;
        };
      };
      renderer = {
        root_folder_label = false;
        highlight_git = true;
        highlight_opened_files = "none";
        indent_markers = {
          enable = true;
        };
        icons = {
          show = {
            file = true;
            folder = true;
            folder_arrow = true;
            git = true;
          };
          glyphs = {
            default = "󰈚";
            symlink = "";
            folder = {
              default = "";
              empty = "";
              empty_open = "";
              open = "";
              symlink = "";
              symlink_open = "";
              arrow_open = "";
              arrow_closed = "";
            };
            git = {
              unstaged = "✗";
              staged = "✓";
              unmerged = "";
              renamed = "➜";
              untracked = "★";
              deleted = "";
              ignored = "◌";
            };
          };
        };
      };
    };
  };

  keymaps = [
    {
      key = "<A-l>";
      action = "<cmd>NvimTreeToggle<CR>";
      options = {
        desc = "Nvimtree Toggle window";
      };
      mode = [ "n" ];
    }
  ];

  highlight = {
    NvimTreeEmptyFolderName = {
      fg = colors.folder_bg;
    };
    NvimTreeEndOfBuffer = {
      fg = colors.darker_black;
    };
    NvimTreeFolderIcon = {
      fg = colors.folder_bg;
    };
    NvimTreeFolderName = {
      fg = colors.folder_bg;
    };
    NvimTreeFolderArrowOpen = {
      fg = colors.folder_bg;
    };
    NvimTreeFolderArrowClosed = {
      fg = colors.grey_fg;
    };
    NvimTreeGitDirty = {
      fg = colors.red;
    };
    NvimTreeIndentMarker = {
      fg = colors.line;
    };
    NvimTreeNormal = {
      bg = colors.darker_black;
    };
    NvimTreeNormalNC = {
      bg = colors.darker_black;
    };
    NvimTreeOpenedFolderName = {
      fg = colors.folder_bg;
    };
    NvimTreeGitIgnored = {
      fg = colors.light_grey;
    };
    NvimTreeWinSeparator = {
      fg = colors.darker_black;
      bg = colors.darker_black;
    };
    NvimTreeWindowPicker = {
      fg = colors.red;
      bg = colors.black2;
    };
    NvimTreeCursorLine = {
      bg = colors.black2;
    };
    NvimTreeGitNew = {
      fg = colors.yellow;
    };
    NvimTreeGitDeleted = {
      fg = colors.red;
    };
    NvimTreeSpecialFile = {
      fg = colors.yellow;
      bold = true;
    };
    NvimTreeRootFolder = {
      fg = colors.red;
      bold = true;
    };
  };
}
