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
  lsp.servers = {
    # config languages
    nixd.enable = true;
    lua_ls.enable = true;

    # bash
    bashls.enable = true;

    # misc
    jsonls.enable = true;
    yamlls.enable = true;
  };

  plugins.lint.lintersByFt.nix = [
    "deadnix"
    "statix"
  ];
  plugins.lint.linters.statix.args = [
    "check"
    "-o"
    "errfmt"
    "--stdin"
    "--config"
    "${pkgs.writeText "statix.toml" ''
      disabled = ['repeated_keys']
    ''}"
  ];

  plugins.conform-nvim.settings.formatters_by_ft = {
    nix = [
      "statix"
      "nixfmt"
    ];
    lua = [ "stylua" ];
    sh = [ "shfmt" ];
  };
  plugins.conform-nvim.settings.formatters.statix = {
    command = "statix";
    args = [
      "fix"
      "--stdin"
    ];
    stdin = true;
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
    deadnix
    statix
  ];
}
