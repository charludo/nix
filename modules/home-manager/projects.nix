{ config, lib, ... }:

let
  cfg = config.projects;
  inherit (lib) mkOption types;
in
{
  options.projects = mkOption {
    type = types.listOf (
      types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "name of the folder created for this project";
          };
          repo = mkOption {
            type = types.str;
            example = "git@github.com:example/project";
            description = "URL of the remote git repo to clone";
          };
          enableDirenv = mkOption {
            type = types.bool;
            default = true;
            description = "whether to create a .direnv file in the project directory";
          };
          flakeURL = mkOption {
            type = types.str;
            default = ".";
            description = "where to find the flake.nix file used for this project";
          };
          writeEnvrc = mkOption {
            type = types.bool;
            default = true;
            description = "do not write an .envrc file, only allow direnv for the project";
          };
        };
      }
    );
    default = [ ];
    description = "projects to automatically create and clone, and what direnv config to add";
  };
  config = lib.mkIf (cfg != [ ]) {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    home.sessionVariables.DIRENV_LOG_FORMAT = "";
    home.file =
      let
        addEntry =
          acc: entry:
          acc
          // {
            "${config.xdg.userDirs.extraConfig.XDG_PROJECTS_DIR}/${entry.name}/.envrc" = {
              text = # bash
                ''
                  ''${DIRENV_DISABLE:+exit}
                  export DIRENV_DISABLE="1"
                  if ([ -f flake.nix ] || [ ${(if entry.flakeURL != "." then "true" else "false")} = true ]) && [ ${
                    (if entry.enableDirenv then "true" else "false")
                  } = true ]; then
                    use flake ${entry.flakeURL}
                  fi
                  if  [ ! -d .git ] && [ -n "${entry.repo}" ]; then
                    git init
                    git remote add origin "${entry.repo}"
                    branch=$(git remote show origin | sed -n '/HEAD branch/s/.*: //p')
                    git pull origin "$branch"
                  fi
                '';
            };
          };
        paths = builtins.concatStringsSep ", " (
          map (entry: ''"${config.xdg.userDirs.extraConfig.XDG_PROJECTS_DIR}/${entry.name}"'') cfg
        );
      in
      (lib.foldl addEntry { } (lib.filter (p: p.writeEnvrc) cfg))
      // {
        ".config/direnv/direnv.toml".text = # toml
          ''
            [global]
            bash_path = "/run/current-system/sw/bin/bash"

            [whitelist]
            exact = [ ${paths} ]
          '';
      };
  };
}
