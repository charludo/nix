local on_attach = require("plugins.configs.lspconfig").on_attach
local capabilities = require("plugins.configs.lspconfig").capabilities

local lspconfig = require("lspconfig")
local util = require("lspconfig/util")

local servers = {
	-- webdev
	"html",
	"cssls",
	"eslint",
	"quick_lint_js",
	"phpactor",

	-- rust
	-- "rust_analyzer", -- done separately

	-- python
	-- "pylsp", -- done separately

	-- misc
	"bashls",
	"jsonls",
	"yamlls",
	"gdscript",
	"ltex",

	-- c
	"clangd",

	-- nix
	"nil_ls",
}

for _, lsp in ipairs(servers) do
	lspconfig[lsp].setup({
		on_attach = on_attach,
		capabilities = capabilities,
	})
end

lspconfig.pylsp.setup({
	on_attach = on_attach,
	capabilities = capabilities,
	filetypes = { "python" },
	settings = {
		pylsp = {
			plugins = {
				pycodestyle = {
					enabled = true,
					ignore = { "E501", "W503", "R0903" },
					maxLineLength = 150,
				},
			},
		},
	},
})

lspconfig.rust_analyzer.setup({
	on_attach = on_attach,
	capabilities = capabilities,
	filetypes = { "rust" },
	root_dir = util.root_pattern("Cargo.toml"),
	settings = {
		["rust-analyzer"] = {
			cargo = {
				allFeatures = true,
			},
		},
	},
})
