{ private-settings, ... }:
{
  imports = [
    ../../../charlotte/home/common/cli/bat.nix
    ../../../charlotte/home/common/cli/fzf.nix
    ../../../common/git.nix
    ../../../common/ssh.nix
  ];

  programs.git = {
    userName = private-settings.git.marie.name;
    userEmail = private-settings.git.marie.email;
  };
}
