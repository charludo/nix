vim.o.number = true
vim.o.termguicolors = true
vim.o.title = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.wildmode = "longest:full,full"
vim.o.wrap = false
vim.o.list = true
vim.o.listchars = "tab:▸ ,trail:·"
vim.o.fillchars = "eob: "
vim.o.mouse = "a"
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.scrolloff = 8
vim.o.sidescrolloff = 8
vim.o.clipboard = "unnamedplus"
vim.o.confirm = true
vim.g.equalalways = false

-- indent
vim.o.expandtab = true
vim.o.shiftwidth = 4
vim.o.tabstop = 4

-- python provider
vim.g.python3_host_prog = "/usr/bin/python"
vim.g.loaded_python3_provider = nil
-- vim.g.loaded_node_provider = nil

-- multi select settings
vim.g.VM_maps = {
  ["Find Under"] = "<C-d>",
  ["Find Subword Under"] = "<C-d>",
}

-- fold settings
vim.wo.foldmethod = "expr"
vim.wo.foldexpr = "nvim_treesitter#foldexpr()"
vim.wo.foldenable = false
vim.wo.foldtext =
  [[substitute(getline(v:foldstart),'\\t',repeat('\ ',&tabstop),'g').'...'.trim(getline(v:foldend)) . ' (' . (v:foldend - v:foldstart + 1) . ' lines)']]
vim.wo.foldnestmax = 3
vim.wo.foldminlines = 1

-- spelling
-- vim.o.spelllang = "en_us,de_de"
