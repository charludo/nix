{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cli.git;
in
{
  options.cli.git.enable = lib.mkEnableOption "git";
  options.cli.git.user.name = lib.mkOption {
    type = lib.types.str;
    description = "git username";
  };
  options.cli.git.user.email = lib.mkOption {
    type = lib.types.str;
    description = "git email address";
  };
  options.cli.git.sshKey.pub = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    description = "path to the public key used by SSH";
  };
  options.cli.git.sshKey.file = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = "${config.home.homeDirectory}/.ssh/id_ed25519";
    defaultText = lib.literalExpression "\${config.home.homeDirectory}/.ssh/id_ed25519.pub";
    description = "path to the private key used by SSH";
  };
  options.cli.git.signingKey.pub = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    description = "path to the public key used for commit signing";
    default = cfg.sshKey.pub;
    defaultText = lib.literalExpression "\${config.cli.git.sshKey.pub}";
  };
  options.cli.git.signingKey.file = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    description = "path to the private key used for commit signing";
    default = cfg.sshKey.file;
    defaultText = lib.literalExpression "\${config.cli.git.sshKey.file}";
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
        "coverage.out"
      ];
      settings = {
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;

        user.name = cfg.user.name;
        user.email = cfg.user.email;

        safe = {
          directory = "${config.home.homeDirectory}/Documents";
        };
        commit.gpgsign = true;
        format = {
          signoff = true;
          numbered = false;
          signature = "";
        };
        am.threeWay = false;
        gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
        gpg.format = "ssh";
        user.signingkey = lib.mkIf (cfg.signingKey.file != null) cfg.signingKey.file;

        core.sshCommand = lib.mkIf (
          cfg.sshKey.file != null
        ) "${lib.getExe' pkgs.openssh "ssh"} -i ${cfg.sshKey.file}";

        alias.ch = "checkout";
        alias.fm = "format-patch --zero-commit --full-index";
      };
    };
    home.file.".ssh/allowed_signers".text = lib.mkIf (
      cfg.signingKey.pub != null
    ) "* ${builtins.readFile cfg.signingKey.pub}";
  };
}
