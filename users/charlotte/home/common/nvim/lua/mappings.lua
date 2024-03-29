local M = {}

M.general = {
  n = {
    ["<C-S-Left>"] = { "<C-w>h", " window left" },
    ["<C-S-Right>"] = { "<C-w>l", " window right" },
    ["<C-S-Down>"] = { "<C-w>j", " window down" },
    ["<C-S-Up>"] = { "<C-w>k", " window up" },

    ["<A-Right>"] = { "$", "goto end of line" },
    ["<A-Left>"] = { "^", "goto start of line" },

    ["<C-A-Right>"] = { "<cmd>vsp<CR>", "open new window to the right" },
    ["<C-A-Down>"] = { "<cmd>sp<CR>", "open new window to the bottom" },

    ["<A-Up>"] = {
      "<cmd>call vm#commands#add_cursor_up(0, v:count1)<CR>",
      "add a cursor below",
      opts = { noremap = true, silent = true },
    },
    ["<A-Down>"] = {
      "<cmd>call vm#commands#add_cursor_down(0, v:count1)<CR>",
      "add a cursor below",
      opts = { noremap = true, silent = true },
    },

    ["<C-S-A-Left>"] = { "20<C-w><", "decrease window width" },
    ["<C-S-A-Right>"] = { "20<C-w>>", "increase window width" },
    ["<C-S-A-Up>"] = { "15<C-w>+", "increase window height" },
    ["<C-S-A-Down>"] = { "15<C-w>-", "decrease window width" },

    ["<A-u>"] = { "guiw", "transform word under cursor to lowercase" },
    ["<A-U>"] = { "gUiw", "transform word under cursor to uppercase" },

    ["<C-Down>"] = { "<cmd> :move +1<CR>", "move current line one down", opts = { noremap = true, silent = true } },
    ["<C-Up>"] = { "<cmd> :move -2<CR>", "move current line one up", opts = { noremap = true, silent = true } },

    ["<leader>p"] = { "<cmd>Project<CR>", "open projectmgr" },

    ["<A-S-t>"] = { "<cmd>tabclose<CR>", "close current tab" },

    ["<leader>gb"] = { "<cmd>Gitsigns toggle_current_line_blame<cr>", "toggle current line blame" },

    ["<leader>gd"] = { "<cmd>normal! gd<cr>", "use nvim's built-in goto definition" },

    ["<leader>tr"] = { "<cmd>Telescope resume<cr>", "re-open last telescope buffer" },

    ["<leader>ts"] = { "<cmd>TSBufToggle highlight<cr>", "toggle tree sitter syntax highlighting" },

    ["<leader>ds"] = {
      "<cmd>lua require('neogen').generate({ type = 'func' })<cr>",
      "generate docstring for a function",
    },
    ["<leader>dc"] = {
      "<cmd>lua require('neogen').generate({ type = 'class' })<cr>",
      "generate docstring for a class",
    },
    ["<leader>df"] = { "<cmd>lua require('neogen').generate({ type = 'file' })<cr>", "generate docstring for a file" },

    ["<leader>gr"] = { "<cmd>GodotRun<cr>", "run Godot scene" },
    ["<leader>gs"] = { "<cmd>GodotRunCurrent<cr>", "run current Godot scene" },

    ["<leader>zm"] = { "<cmd>TZMinimalist<cr>", "TrueZen minimalist" },
    ["<leader>za"] = { "<cmd>TZAtaraxis<cr>", "TrueZen ataraxis" },

    ["<C-a>"] = { "<cmd>ChatGPT<CR>", "Open ChatGPT" },
  },
  i = {
    ["<A-Right>"] = { "<cmd>ASToggle<cr><ESC>A<cmd>ASToggle<cr>", "goto end of line" },
    ["<A-Left>"] = { "<cmd>ASToggle<cr><ESC>I<cmd>ASToggle<cr>", "goto start of line" },

    ["<C-Down>"] = { "<cmd> :move +1<CR>", "move current line one down" },
    ["<C-Up>"] = { "<cmd> :move -2<CR>", "move current line one up" },

    ["<C-s>"] = { "<cmd> :w<CR>", "save current buffer" },
  },
  v = {
    ["<A-Right>"] = { "$", "goto end of line" },
    ["<A-Left>"] = { "^", "goto start of line" },
    ["<leader>re"] = {
      "<cmd>lua require('react-extract').extract_to_new_file()<CR>",
      "extract react component to new file",
    },
    ["<leader>rc"] = {
      "<cmd>lua require('react-extract').extract_to_current_file()<CR>",
      "extract react component to current file",
    },
    ["<leader>zn"] = { "<cmd>TZNarrow<cr>", "TrueZen narrow (for selection)" },

    ["<C-a>"] = { "<cmd>ChatGPTEditWithInstruction<CR>", "Open ChatGPT in edit mode" },
  },
}

M.nvimtree = {
  n = {
    ["<A-q>"] = { "<cmd> :wq<CR>", "save and close all" },
    ["<S-A-q>"] = { "<cmd> :wqa<CR>", "save and close all" },
    ["<A-l>"] = { "<cmd>NvimTreeToggle<CR>", "toggle tree" },
  },
}

M.comment = {
  i = {
    ["<A-/>"] = {
      function()
        require("Comment.api").locked "toggle.linewise.current"()
      end,

      "蘒  toggle comment",
    },
  },
  n = {
    ["<A-/>"] = {
      function()
        require("Comment.api").locked "toggle.linewise.current"()
      end,

      "蘒  toggle comment",
    },
  },

  v = {
    ["<A-/>"] = {
      "<ESC><cmd>lua require('Comment.api').locked('toggle.linewise')(vim.fn.visualmode())<CR>",
      "蘒  toggle comment",
    },
  },
}

M.dap = {
  plugin = true,
  n = {
    ["<leader>db"] = { "<cmd> DapToggleBreakpoint <CR>", "toggle a dap breakpoint" },
    ["<leader>dr"] = { "<cmd> DapContinue <CR>", "start or continue the debugger" },
  },
}

M.crates = {
  n = {
    ["<leader>cu"] = {
      function()
        require("crates").upgrade_all_crates()
      end,
      "update all crates",
    },
  },
}

return M
