{ private-settings, ... }:
{
  imports = [
    ./common
    ./common/cli.nix
  ];
  home.hostname = "CL-ROU";

  cli = {
    bat.enable = true;
    fish.enable = true;
    fzf.enable = true;
    gh.enable = true;
    git = {
      enable = true;
      sshKey.pub = ../keys/ssh.pub;
      user.name = private-settings.git.charlotte.name;
      user.email = private-settings.git.charlotte.email;
    };
    tmux.enable = true;
  };

  programs.fish.interactiveShellInit = # fish
    ''
      if set -q SSH_TTY; and not set -q TMUX
        exec tmux new-session -A -s main
      end
    '';

  inherit (private-settings) projects;
  nixvim.addDesktopEntry = false;
  nixvim.languages = {
    python.enable = true;
    rust.enable = true;
    webdev.enable = true;
  };
}
