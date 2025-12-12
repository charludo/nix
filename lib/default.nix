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
        ci = import ./ci.nix { inherit lib; };
        colors = import ./colors.nix { inherit lib; };
        helpers = import ./helpers.nix { inherit lib outputs; };
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
