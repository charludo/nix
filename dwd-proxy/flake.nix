{
  description = "Caching proxy and prefetcher for the DWD radar WMS service";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      treefmt-nix,
    }:
    {
      # Exposed outside eachDefaultSystem so `imports = [ dwd-proxy.nixosModules.default ]`
      # works from a consuming flake without naming a system.
      nixosModules.default = import ./nix/module.nix self;

      overlays.default = final: _prev: {
        dwd-proxy = final.callPackage ./nix/package.nix {
          version = final.lib.trim (builtins.readFile ./version.txt);
        };
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs) lib;
        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

        dwd-proxy = pkgs.callPackage ./nix/package.nix {
          version = lib.trim (builtins.readFile ./version.txt);
        };
      in
      {
        packages = {
          default = dwd-proxy;
          inherit dwd-proxy;
        };

        formatter = treefmtEval.config.build.wrapper;

        checks = {
          formatting = treefmtEval.config.build.check self;
          # Building the package runs `go test -race ./...` in its checkPhase.
          tests = dwd-proxy;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            go
            golangci-lint
            gotools
            gopls
            govulncheck
          ];
        };
      }
    );
}
