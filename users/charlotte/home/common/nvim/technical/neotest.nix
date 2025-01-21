{ config, lib, ... }:
let
  colors = import ../colors.nix { inherit config lib; };
in
{
  programs.nixvim.plugins.neotest = {
    enable = true;
    settings = {
      diagnostic.severity = "hint";
      output.enabled = false;
      # Copied from the docs for easy reference
      summary.mappings = {
        attach = "a";
        clear_marked = "M";
        clear_target = "T";
        debug = "d";
        debug_marked = "D";
        expand = [
          "<CR>"
          "<Tab>"
        ];
        expand_all = "e";
        jumpto = "i";
        mark = "m";
        next_failed = "J";
        output = "o";
        prev_failed = "K";
        run = "r";
        run_marked = "R";
        short = "O";
        stop = "u";
        target = "t";
        watch = "w";
      };
    };
    adapters.python.enable = true;
    adapters.rust.enable = true;
  };

  programs.nixvim.keymaps = [
    {
      key = "<leader>tt";
      action = "<cmd>lua require('neotest').run.run()<CR>";
      options = {
        desc = "Run the nearest test";
      };
      mode = [ "n" ];
    }
    {
      key = "<leader>tf";
      action = "<cmd>lua require('neotest').run.run(vim.fn.expand('%'))<CR>";
      options = {
        desc = "Run the current file";
      };
      mode = [ "n" ];
    }
    {
      key = "<leader>td";
      action = "<cmd>lua require('neotest').run.run({strategy = 'dap'})<CR>";
      options = {
        desc = "Debug the nearest test";
      };
      mode = [ "n" ];
    }
    {
      key = "<leader>tw";
      action = "<cmd>lua require('neotest').watch.toggle(vim.fn.expand('%'))<CR>";
      options = {
        desc = "Toggle watching the current file";
      };
      mode = [ "n" ];
    }
    {
      key = "<leader>to";
      action = "<cmd>lua require('neotest').output_panel.toggle()<CR>";
      options = {
        desc = "Toggle the neotest output panel";
      };
      mode = [ "n" ];
    }
    {
      key = "<leader>tu";
      action = "<cmd>lua require('neotest').summary.toggle()<CR>";
      options = {
        desc = "Toggle the neotest summary panel";
      };
      mode = [ "n" ];
    }
  ];

  programs.nixvim.highlight = {
    NeotestPassed = {
      fg = colors.base0B;
    };
    NeotestFailed = {
      fg = colors.base08;
    };
    NeotestRunning = {
      fg = colors.base0A;
    };
    NeotestSkipped = {
      fg = colors.base0D;
    };
    NeotestTest = {
      fg = colors.base05;
    };
    NeotestNamespace = {
      fg = colors.base0E;
    };
    NeotestFocused = {
      fg = colors.base07;
      bold = true;
      underline = true;
    };
    NeotestFile = {
      fg = colors.base0D;
    };
    NeotestDir = {
      fg = colors.base0D;
    };
    NeotestIndent = {
      fg = colors.line;
    };
    NeotestExpandMarker = {
      fg = colors.line;
    };
    NeotestAdapterName = {
      fg = colors.base08;
    };
    NeotestWinSelect = {
      fg = colors.base0D;
      bold = true;
    };
    NeotestMarked = {
      fg = colors.base09;
      bold = true;
    };
    NeotestTarget = {
      fg = colors.base08;
    };
    NeotestWatching = {
      fg = colors.base0A;
    };
    NeotestUnknown = {
      fg = colors.base05;
    };
  };
}
