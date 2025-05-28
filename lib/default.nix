{ lib, ... }:
{
  colors = import ./colors.nix { inherit lib; };
}
