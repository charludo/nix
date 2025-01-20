{ config, private-settings, ... }:
{
  imports = [
    ../../../../common/git.nix
  ];

  home.file.".ssh/allowed_signers".text = "* ${builtins.readFile ../../../ssh.pub}";
  programs.git = {
    userName = private-settings.git.charlotte.name;
    userEmail = private-settings.git.charlotte.email;
    extraConfig = {
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
