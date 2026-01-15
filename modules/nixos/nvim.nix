{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.nvim;
in
{
  options.nvim = {
    enable = lib.mkEnableOption "NeoVim and make default editor";
    package = lib.mkOption {
      type = lib.types.package;
      description = "Package to use. Defaults to custom nixvim package provided by this flake.";
      default = pkgs.ours.nvim;
      defaultText = lib.literalExpression "pkgs.ours.nvim";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    environment.variables.EDITOR = lib.mkOverride 900 "nvim";
  };
}
