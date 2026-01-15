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
    ./sql.nix
    ./webdev.nix
  ];
  plugins.lsp.servers = {
    # config languages
    nil_ls.enable = true;
    lua_ls.enable = true;

    # bash
    bashls.enable = true;

    # misc
    jsonls.enable = true;
    yamlls.enable = true;
  };

  plugins.conform-nvim.settings.formatters_by_ft = {
    nix = [ "nixfmt" ];
    lua = [ "stylua" ];
    sh = [ "shfmt" ];
  };
  plugins.conform-nvim.settings.formatters.shfmt.args = [
    "-sr"
    "-kp"
    "-i"
    "4"
    "-filename"
    "$FILENAME"
  ];
  extraPackages = with pkgs; [
    nixfmt
    stylua
    shfmt
  ];
}
