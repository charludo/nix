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

  hass-remembrance = callPackage ./by-name/hass-remembrance/package.nix {
    inherit (basePackages) duckling;
  };

  home-assistant =
    basePackages.home-assistant
    // {
      custom-components = basePackages.home-assistant.custom-components // {
        brother_ptouch = callPackage ./by-name/home-assistant/custom-components/brother-ptouch.nix {
          src = inputs.haos-labelprinter;
        };
      };
    }
    // inputs.hass-custom-integrations.packages.${pkgs.stdenv.hostPlatform.system};
}
