{
  inputs,
  lib,
  pkgs,
}:
let
  callPackage = lib.callPackageWith pkgs;
in
lib.packagesFromDirectoryRecursive {
  callPackage = lib.callPackageWith pkgs;
  directory = ./by-name;
}
// {
  nvim = callPackage ./by-name/nvim/package.nix {
    inherit lib;
    inherit (inputs) nixvim;
  };
}
