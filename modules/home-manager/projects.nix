{ lib, ... }:

let
  inherit (lib) mkOption types;
in
{
  options.projects = mkOption {
    type = types.listOf (
      types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            example = "projectname";
          };
          repo = mkOption {
            type = types.str;
            example = "git@github.com:example/project";
            default = "";
          };
          enableDirenv = mkOption {
            type = types.bool;
            default = true;
          };
        };
      }
    );
    default = [ ];
  };
  config = { };
}
