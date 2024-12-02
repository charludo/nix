{
  inputs,
  pkgs,
}:
let
  inherit (pkgs) lib;
  callPackage = lib.callPackageWith pkgs;
  basePackages = lib.packagesFromDirectoryRecursive {
    callPackage = lib.callPackageWith pkgs;
    directory = ./by-name;
  };
in
basePackages
// {
  nvim = callPackage ./by-name/nvim/package.nix {
    inherit (inputs) nixvim;
  };

  home-assistant =
    basePackages.home-assistant
    // {
      custom-components = callPackage ./by-name/home-assistant/custom-components/package.nix {
        hass-closest-intent-src = inputs.hass-closest-intent;
      };
    }
    // inputs.hass-custom-integrations.packages.${pkgs.stdenv.hostPlatform.system};
}
