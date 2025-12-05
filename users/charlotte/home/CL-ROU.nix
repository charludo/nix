{ pkgs, private-settings, ... }:
{
  imports = [
    ./common
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
  };

  home.packages = [ pkgs.tmux ];

  projects = private-settings.projects;
  nixvim.addDesktopEntry = false;
  nixvim.languages = {
    python.enable = true;
    rust.enable = true;
    webdev.enable = true;
  };
}
