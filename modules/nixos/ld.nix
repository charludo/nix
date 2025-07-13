{
  config,
  lib,
  pkgs,
  options,
  ...
}:

with lib;
let
  cfg = config.ld;
in
{
  options.ld = {
    enable = lib.mkEnableOption "dynamic linking of libraries";

    additionalPackages = mkOption {
      type = types.listOf (types.path);
      default = [ pkgs.ruff ];
      defaultText = lib.literalExpression ''[ pkgs.ruff ]'';
      description = "add additional packages for which to enable dynamic linking";
    };

    bool = mkOption {
      type = types.bool;
      default = false;
      description = "";
    };
  };

  config = mkIf cfg.enable {
    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = cfg.additionalPackages ++ options.programs.nix-ld.libraries.default;
  };
}
