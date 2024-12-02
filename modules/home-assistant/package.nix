{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hass.package;
  hasPython = cfg.pythonPackageOverrides != [ ];
  hasPostPatch = cfg.postPatch != "";

  base =
    if hasPython then
      pkgs.home-assistant.override {
        packageOverrides =
          self: super: lib.foldl' (acc: f: acc // (f self super)) { } cfg.pythonPackageOverrides;
      }
    else
      pkgs.home-assistant;
in
{
  options.hass.package = {
    pythonPackageOverrides = lib.mkOption {
      type = lib.types.listOf (lib.mkOptionType {
        name = "packageOverrides function";
        check = lib.isFunction;
      });
      default = [ ];
      description = "Functions `self: super: { ... }` merged into HA's Python packageOverrides.";
    };

    postPatch = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra postPatch shell script for the home-assistant derivation.";
    };
  };

  config = lib.mkIf (hasPython || hasPostPatch) {
    services.home-assistant.package =
      if hasPostPatch then
        base.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + "\n" + cfg.postPatch;
        })
      else
        base;
  };
}
