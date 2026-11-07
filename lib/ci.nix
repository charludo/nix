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

  nixosConfigurationsFor =
    flake: system:
    lib.filterAttrs (_: cfg: cfg.pkgs.stdenv.hostPlatform.system == system) flake.nixosConfigurations;

  fromNixosConfigurations =
    flake: system:
    lib.mapAttrs (_: cfg: cfg.config.system.build.toplevel) (nixosConfigurationsFor flake system);

  fromSnowConfigurations =
    flake: system: lib.mapAttrs (_: cfg: cfg.config.snow) (nixosConfigurationsFor flake system);

  allOutputs = flake: system: {
    nixosConfigurations = fromNixosConfigurations flake system;
    snow = fromSnowConfigurations flake system;
    packages = lib.unique (
      lib.concatMap (from: from flake system) [
        fromPackageOutputs
        fromNixvimPackages
      ]
    );
  };
}
