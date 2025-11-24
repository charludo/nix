{ inputs, outputs }:
{
  # For every flake input, aliases 'pkgs.inputs.${flake}' to
  # 'inputs.${flake}.packages.${pkgs.system}' or
  # 'inputs.${flake}.legacyPackages.${pkgs.system}'
  flake-inputs = final: _: {
    inputs = builtins.mapAttrs (
      _: flake:
      let
        legacyPackages = ((flake.legacyPackages or { }).${final.stdenv.hostPlatform.system} or { });
        packages = ((flake.packages or { }).${final.stdenv.hostPlatform.system} or { });
      in
      if legacyPackages != { } then legacyPackages else packages
    ) inputs;
  };
  pkgs = (
    _: prev: {
      ours = outputs.packages.${prev.stdenv.hostPlatform.system};
    }
  );
}
