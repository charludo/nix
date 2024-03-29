return {
  { "folke/which-key.nvim", lazy = false },
  {
    "Pocco81/true-zen.nvim",
    lazy = false,
    config = function()
      require("true-zen").setup {}
    end,
  },
  {
    "danymat/neogen",
    config = function()
      require("neogen").setup {
        languages = {
          python = {
            template = {
              annotation_convention = "reST",
            },
          },
        },
      }
    end,
  },
  { "tpope/vim-fugitive", lazy = false },
  {
    "Pocco81/auto-save.nvim",
    lazy = false,
    config = function()
      require("auto-save").setup {
        enabled = true,
        trigger_events = { "InsertLeave" },
        debounce_delay = 230,
      }
    end,
  },
  { "jessarcher/vim-heritage", lazy = false },
  { "tpope/vim-eunuch", lazy = false },
  { "mg979/vim-visual-multi", lazy = false },
  {
    "charludo/projectmgr.nvim",
    -- dir = "/home/charlotte/Projekte/projectmgr.nvim",
    -- dev = true,
    lazy = false,
    config = function()
      require("projectmgr").setup {
        autogit = {
          enabled = false,
        },
        reopen = true,
      }
    end,
  },
  {
    "nvim-tree/nvim-tree.lua",
    opts = {
      git = { enable = true, ignore = true },
      view = { width = 35, adaptive_size = false },
      renderer = { highlight_git = true, icons = { show = { git = true } } },
      actions = { open_file = { resize_window = false } },
    },
  },
  { "habamax/vim-godot", event = "BufEnter *.gd" },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "jose-elias-alvarez/null-ls.nvim",
      config = function()
        require "custom.configs.null-ls"
      end,
    },
    config = function()
      require "plugins.configs.lspconfig"
      require "custom.configs.lspconfig"
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    opts = require "custom.configs.cmp",
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = require "custom.configs.treesitter",
  },
  {
    "williamboman/mason.nvim",
    opts = require "custom.configs.mason",
  },
  {
    "lervag/vimtex",
    lazy = false,
    config = function()
      vim.g.vimtex_view_method = "sioyek"
    end,
  },
  {
    "L3MON4D3/LuaSnip",
    version = "v2.*",
  },
  { "MunifTanjim/nui.nvim" },
  { "nvim-lua/plenary.nvim" },
  -- {
  -- "jackMort/ChatGPT.nvim",
  -- event = "VeryLazy",
  -- config = function()
  -- require("chatgpt").setup {
  -- api_key_cmd = "bw get notes OpenAI-nvim",
  -- }
  -- end,
  -- dependencies = {
  -- "MunifTanjim/nui.nvim",
  -- "nvim-lua/plenary.nvim",
  -- "nvim-telescope/telescope.nvim",
  -- },
  -- },
  {
    "mfussenegger/nvim-dap",
    config = function()
      -- require "custom.configs.dap"
      require("core.utils").load_mappings "dap"
    end,
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = { "williamboman/mason.nvim", "mfussenegger/nvim-dap" },
    opts = { handlers = {} },
    event = "VeryLazy",
  },
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap" },
    event = "VeryLazy",
    config = function()
      local dap = require "dap"
      local dapui = require "dapui"
      dapui.setup()
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end,
  },
  {
    "rust-lang/rust.vim",
    ft = { "rust" },
    init = function()
      vim.g.rustfmt_autosave = 1
    end,
  },
  {
    "saecki/crates.nvim",
    ft = { "rust", "toml" },
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("crates").setup()
    end,
  },
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
}
