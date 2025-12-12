{ lib, ... }:
rec {
  fromPackageOutputs =
    flake: system:
    lib.concatMap (kind: lib.attrValues (lib.attrByPath [ kind system ] { } flake)) [
      "packages"
      "checks"
      "devShells"
    ];

  fromNixvimPackages =
    flake: system:
    lib.attrValues (
      lib.filterAttrs (_: v: lib.isDerivation v) (lib.attrByPath [ "packages" system "nvim" ] { } flake)
    );

  fromNixosConfigurations =
    flake: system:
    lib.map (cfg: cfg.config.system.build.toplevel) (
      lib.attrValues (
        lib.filterAttrs (_: cfg: cfg.pkgs.stdenv.hostPlatform.system == system) flake.nixosConfigurations
      )
    );

  allOutputs =
    flake: system:
    lib.unique (
      lib.concatMap (from: from flake system) [
        fromPackageOutputs
        fromNixvimPackages
        fromNixosConfigurations
      ]
    );
}
