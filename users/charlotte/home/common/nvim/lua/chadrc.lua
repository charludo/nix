require "custom.padding"

-- vim.api.nvim_exec([[autocmd bufwritepost [^_]*.sass,[^_]*.scss  silent exec "!sass %:p %:r.css"]], false)
vim.api.nvim_exec([[autocmd VimEnter * hi Folded guibg=ctermbg]], false)

local M = {}

M.plugins = "custom.plugins"
M.mappings = require "custom.mappings"

M.ui = {
  theme = "gruvchad",
  -- changed_themes = {
  -- gruvchad = {
  -- base_16 = { base00 = "#222222" },
  -- base_30 = { base00 = "#222222" },
  -- },
  -- },
  tabufline = {
    lazyload = false,
    overriden_modules = nil,
  },
  cmp = {
    style = "flat_dark",
  },
}

return M
