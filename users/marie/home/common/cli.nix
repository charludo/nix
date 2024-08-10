{ inputs, ... }:
{
  imports = [
    ../../../charlotte/home/common/cli/bat.nix
    ../../../charlotte/home/common/cli/fzf.nix
    ../../../common/git.nix
    ../../../common/ssh.nix
  ];

  programs.git = {
    userName = inputs.private-settings.git.marie.name;
    userEmail = inputs.private-settings.git.marie.email;
  };
}
