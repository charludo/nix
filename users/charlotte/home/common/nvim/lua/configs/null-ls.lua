local null_ls = require("null-ls")

local code_actions = null_ls.builtins.code_actions
local completion = null_ls.builtins.completion
local diagnostics = null_ls.builtins.diagnostics
local formatting = null_ls.builtins.formatting

local sources = {
	-- lua
	formatting.stylua,

	-- python
	diagnostics.pylint,
	-- diagnostics.mypy,
	formatting.black,

	--rust
	formatting.rustfmt,

	-- javascript
	formatting.prettierd,
	diagnostics.jsonlint,
	code_actions.eslint,
	diagnostics.eslint,

	-- web
	diagnostics.djlint,
	formatting.djlint.with({ filetypes = { "jinja", "jinja.html", "twig", "htmldjango", "django", "html" } }),
	formatting.stylelint,

	-- misc
	diagnostics.codespell,
	diagnostics.stylelint,
	completion.spell,

	-- godot
	formatting.gdformat,
	diagnostics.gdlint.with({ filetypes = { "gd", "gdscript", "gdscript3" } }),

	-- LaTeX
	diagnostics.chktex,
	formatting.latexindent,

	-- c
	formatting.clang_format,

	-- nix
	formatting.nixpkgs_fmt,
}

null_ls.setup({
	debug = true,
	sources = sources,
	-- format on save
	on_attach = function(client)
		if client.server_capabilities.documentFormattingProvider then
			vim.cmd("autocmd BufWritePre <buffer> lua vim.lsp.buf.format()")
		end
	end,
})
