{
  config,
  lib,
  pkgs,
  outputs,
  ...
}:

with lib;
let
  cfg = config.nvim;
in
{
  options.nvim = {
    enable = lib.mkEnableOption (lib.mdDoc "enable NeoVim and make default editor");
    package = lib.mkOption {
      type = lib.types.package;
      description = "Package to use. Defaults to custom nixvim package provided by this flake.";
      default = outputs.packages.${pkgs.system}.nvim;
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    environment.variables.EDITOR = lib.mkOverride 900 "nvim";
  };
}
