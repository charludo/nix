{ inputs, lib, ... }:
let
  inherit (inputs.nix-colors) colorschemes;
in
{
  imports = [
    ./common
    ./common/nvim
    ./common/games/eso.nix
  ];

  colorscheme = lib.mkDefault colorschemes.primer-dark-dimmed;
}
