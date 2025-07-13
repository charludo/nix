{ inputs, outputs }:
_: prev: {
  ours = prev.pkgs.callPackage ../pkgs {
    inherit inputs;
    pkgs = prev.pkgs;
  };
  lib =
    prev.lib
    // import ../lib {
      inherit inputs outputs;
      pkgs = prev.pkgs;
    };
}
