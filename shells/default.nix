{
  lib,
  callPackage,
}:

let
  self =
    lib.packagesFromDirectoryRecursive {
      inherit callPackage;
      directory = ./by-name;
    }
    // {
      default = self.dev;
    };
in
self
