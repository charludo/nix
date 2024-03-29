return {
	ensure_installed = {
		-- lua
		"stylua",
		"lua-language-server",

		-- python
		"black",
		-- "pylint",
		-- "pyright",
		-- "python-lsp-server",
		-- "mypy",
		"djlint",

		-- rust
		"rust-analyzer",

		-- javascript
		"json-lsp",
		"quick-lint-js",
		"typescript-language-server",
		"eslint_d",
		"prettierd",
		-- "js-debug-adapter",

		-- web
		"html-lsp",
		"css-lsp",
		"phpactor",

		-- misc
		"bash-language-server",
		"yaml-language-server",
		"yamllint",
		"ltex-ls",

		-- c
		"clangd",
		"clang-format",
		"codelldb",

		-- nix
		"nil",
		"nixpgs-fmt",
	},
}
