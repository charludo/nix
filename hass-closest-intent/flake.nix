{
  description = "Closest Intent — fuzzy-fallback conversation agent for Home Assistant.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Mirror of the dependency groups in pyproject.toml. Keep these
        # in sync — pyproject.toml is the source of truth for non-Nix
        # contributors, this list is the source of truth for `nix
        # develop` users.
        pythonEnv = pkgs.python3.withPackages (
          ps: with ps; [
            # Runtime
            rapidfuzz
            voluptuous
            # Test
            pytest
            pytest-asyncio
            pyyaml
          ]
        );

        # Tooling: pinned to the nixpkgs versions so a single
        # `nix flake update` updates everything together.
        devTools = with pkgs; [
          ruff
          mypy
        ];
      in
      {
        # `nix develop` (or `nix-shell` via the compatibility shim) →
        # python with all deps + ruff + mypy on PATH. Tests run as
        # `pytest tests/` directly.
        devShells.default = pkgs.mkShell {
          name = "closest-intent-dev";
          packages = [ pythonEnv ] ++ devTools;

          shellHook = ''
            echo "closest_intent dev shell"
            echo "  python:    $(${pythonEnv}/bin/python --version)"
            echo "  ruff:      $(${pkgs.ruff}/bin/ruff --version)"
            echo "  mypy:      $(${pkgs.mypy}/bin/mypy --version)"
            echo
            echo "Common tasks:"
            echo "  pytest tests/                  run the test suite"
            echo "  ruff check .                   lint"
            echo "  ruff format .                  format"
            echo "  mypy custom_components/        type-check"
          '';
        };

        # `nix flake check` runs the test suite in a sandbox. CI can
        # call this directly without needing a separate test runner.
        checks = {
          tests = pkgs.runCommand "closest-intent-tests" {
            nativeBuildInputs = [ pythonEnv ];
            src = self;
          } ''
            cp -r $src/. ./work
            chmod -R u+w ./work
            cd ./work
            export PYTEST_CACHE_DIR="$TMPDIR/pytest-cache"
            ${pythonEnv}/bin/pytest tests/ -v -o cache_dir="$PYTEST_CACHE_DIR"
            touch $out
          '';

          lint = pkgs.runCommand "closest-intent-lint" {
            nativeBuildInputs = [ pkgs.ruff ];
            src = self;
          } ''
            cp -r $src/. ./work
            chmod -R u+w ./work
            cd ./work
            export RUFF_CACHE_DIR="$TMPDIR/ruff-cache"
            ${pkgs.ruff}/bin/ruff check .
            ${pkgs.ruff}/bin/ruff format --check .
            touch $out
          '';
        };

        # `nix fmt` formats Nix files in this repo.
        formatter = pkgs.nixfmt;
      }
    );
}
