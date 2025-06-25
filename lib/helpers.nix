{ lib, ... }:
rec {
  mkImports = dir: lib.filesystem.listFilesRecursive dir;
  mkImportsNoDefault = dir: lib.filter (f: baseNameOf f != "default.nix") (mkImports dir);
}
