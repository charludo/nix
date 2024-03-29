{ config, ... }:
{
  programs.git = {
    enable = true;
    userName = "charludo";
    userEmail = "github@charlotteharludo.com";
    ignores = [ "Session.vim" "main.shada" ];
    extraConfig = {
      init = { defaultBranch = "main"; };
      pull = { rebase = true; };
      push = { autoSetupRemote = true; };
      safe = {
        directory = "${config.home.homeDirectory}/Documents";
      };
    };
  };
}
