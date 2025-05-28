{ pkgs, ... }:
{
  imports = [
    ./c.nix
    ./go.nix
    ./godot.nix
    ./haskell.nix
    ./latex.nix
    ./python.nix
    ./rust.nix
    ./webdev.nix
  ];
  programs.nixvim.plugins.lsp.servers = {
    # config languages
    nil_ls.enable = true;
    lua_ls.enable = true;

    # bash
    bashls.enable = true;

    # misc
    jsonls.enable = true;
    yamlls.enable = true;
  };

  programs.nixvim.plugins.conform-nvim.settings.formatters_by_ft = {
    nix = [ "nixfmt" ];
    lua = [ "stylua" ];
    sh = [ "shfmt" ];
  };
  programs.nixvim.plugins.conform-nvim.settings.formatters.shfmt.args = [
    "-sr"
    "-kp"
    "-i"
    "4"
    "-filename"
    "$FILENAME"
  ];
  programs.nixvim.extraPackages = with pkgs; [
    nixfmt-rfc-style
    stylua
    shfmt
  ];
}
