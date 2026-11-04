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
      lib.filterAttrs (n: v: n != "nixvimExtend" && lib.isDerivation v) (
        lib.attrByPath [ "packages" system "nvim" ] { } flake
      )
    );

  fromNixosConfigurations =
    flake: system:
    lib.mapAttrs (_: cfg: cfg.config.system.build.toplevel) (
      lib.filterAttrs (_: cfg: cfg.pkgs.stdenv.hostPlatform.system == system) flake.nixosConfigurations
    );

  allOutputs = flake: system: {
    nixosConfigurations = fromNixosConfigurations flake system;
    packages = lib.unique (
      lib.concatMap (from: from flake system) [
        fromPackageOutputs
        fromNixvimPackages
      ]
    );
  };
}
