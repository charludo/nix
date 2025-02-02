{ inputs, lib, ... }:
let
  inherit (inputs.nix-colors) colorSchemes;
in
{
  imports = [
    ./common
    ./common/nvim
    ./common/games/eso.nix
  ];

  colorScheme = lib.mkDefault colorSchemes.primer-dark-dimmed;
  home.hostname = "steamdeck";
}
