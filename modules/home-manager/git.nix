{ config, lib, ... }:
let
  cfg = config.cli.git;
in
{
  options.cli.git.enable = lib.mkEnableOption "enable and configure git";
  options.cli.git.user.name = lib.mkOption { type = lib.types.str; };
  options.cli.git.user.email = lib.mkOption { type = lib.types.str; };
  options.cli.git.signingKey.pub = lib.mkOption { type = lib.types.nullOr lib.types.path; };
  options.cli.git.signingKey.file = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
  };

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      ignores = [
        "Session.vim"
        "main.shada"
        ".envrc"
        ".direnv"
        ".venv"
        ".dmypy.json"
      ];
      extraConfig = {
        init = {
          defaultBranch = "main";
        };
        pull = {
          rebase = true;
        };
        push = {
          autoSetupRemote = true;
        };
      };

      userName = cfg.user.name;
      userEmail = cfg.user.email;
      extraConfig = {
        safe = {
          directory = "${config.home.homeDirectory}/Documents";
        };
        commit.gpgsign = true;
        format.signoff = true;
        gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
        gpg.format = "ssh";
        user.signingkey = lib.mkIf (cfg.signingKey.file != null) cfg.signingKey.file;
      };
    };
    home.file.".ssh/allowed_signers".text = lib.mkIf (
      cfg.signingKey.pub != null
    ) "* ${builtins.readFile cfg.signingKey.pub}";
  };
}
