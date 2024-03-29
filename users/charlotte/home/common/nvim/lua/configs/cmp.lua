local types = require "cmp.types"

local options = require "plugins.configs.cmp"
options["completion"] = { completeopt = "menu,menuone,noselect" }
options["sources"] = {
  {
    name = "nvim_lsp",
    entry_filter = function(entry, _)
      return types.lsp.CompletionItemKind[entry:get_kind()] ~= "Text"
    end,
    priority = 6,
  },
  { name = "luasnip", priority = 4 },
  { name = "buffer", priority = 3 },
  { name = "nvim_lua", priority = 4 },
  { name = "path", priority = 5 },
}
return options
