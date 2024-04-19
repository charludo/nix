{ pkgs, ... }:
{
  imports = [
    ./c.nix
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
    lua-ls.enable = true;

    # bash
    bashls.enable = true;

    # misc
    jsonls.enable = true;
    yamlls.enable = true;
  };

  programs.nixvim.plugins.conform-nvim.formattersByFt = {
    nix = [ "nixpkgs_fmt" ];
    lua = [ "stylua" ];
    sh = [ "shfmt" ];
  };
  programs.nixvim.plugins.conform-nvim.formatters.shfmt.args = [ "-sr" "-kp" "-i" "4" "-filename" "$FILENAME" ];
  programs.nixvim.extraPackages = with pkgs; [ nixpkgs-fmt stylua shfmt ];
}
