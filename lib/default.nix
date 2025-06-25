{
  pkgs,
  inputs,
  outputs,
}:

let
  mkLib =
    nixpkgs:
    nixpkgs.lib.extend (
      self: _:
      let
        lib = self;
      in
      {
        helpers = import ./helpers.nix { inherit lib; };
        colors = import ./colors.nix { inherit lib; };
        mkConfigs = import ./mkConfigs.nix {
          inherit
            lib
            pkgs
            inputs
            outputs
            ;
        };
      }
      // inputs.home-manager.lib
    );
  lib = mkLib inputs.nixpkgs;
in
lib
