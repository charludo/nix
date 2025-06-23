{ lib, pkgs }:

lib.packagesFromDirectoryRecursive {
  callPackage = lib.callPackageWith pkgs;
  directory = ./by-name;
}
// { }
