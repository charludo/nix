{ lib, ... }:
{
  imports = (lib.helpers.mkImportsNoDefault ./.) ++ [ ../nixos/age.nix ];
}
