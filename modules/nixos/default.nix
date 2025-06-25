{ lib, ... }:
{
  imports = lib.helpers.mkImportsNoDefault ./.;
}
