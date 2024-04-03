{ config, ... }:
{
  home.file.".ssh/allowed_signers".text = "* ${builtins.readFile ../../../ssh.pub}";
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
      commit.gpgsign = true;
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      gpg.format = "ssh";
      user.signingkey = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
    };
  };
}
