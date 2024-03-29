{
  imports = [
    ./c.nix
    ./godot.nix
    ./latex.nix
    ./python.nix
    ./rust.nix
    ./webdev.nix
  ];
  programs.nixvim.plugins.lsp.servers = {
    # config languages
    nil_ls.enable = true;
    lua-ls.enable = true;

    # bash
    bashls.enable = true;

    # misc
    jsonls.enable = true;
    yamlls.enable = true;
  };
  programs.nixvim.plugins.none-ls.sources = {
    # config languages 
    formatting.nixpkgs_fmt.enable = true;
    formatting.stylua.enable = true;

    # bash
    diagnostics.zsh.enable = true;
    formatting.shfmt.enable = true;

    # spelling
    diagnostics.codespell.enable = true;
    diagnostics.stylelint.enable = true;
    completion.spell.enable = true;
  };
}
