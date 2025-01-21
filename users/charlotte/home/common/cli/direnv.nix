{ config, lib, ... }:
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
            if [ -f flake.nix ] && [ ${(if entry.enableDirenv then "true" else "false")} = true ]; then
              use flake .
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
    map (entry: ''"${config.xdg.userDirs.extraConfig.XDG_PROJECTS_DIR}/${entry.name}"'') config.projects
  );
in
{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  home.sessionVariables.DIRENV_LOG_FORMAT = "";
  home.file = (lib.foldl addEntry { } config.projects) // {
    ".config/direnv/direnv.toml".text = # toml
      ''
        [global]
        bash_path = "/run/current-system/sw/bin/bash"

        [whitelist]
        exact = [ ${paths} ]
      '';
  };
}
