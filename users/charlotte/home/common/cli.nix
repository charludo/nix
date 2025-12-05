{
  config,
  lib,
  private-settings,
  secrets,
  ...
}:
let
  inherit (private-settings) gsv;
in
{
  cli = {
    bat.enable = true;
    bitwarden = {
      enable = true;
      email = private-settings.email.vaultwarden;
      url = "https://passwords.${private-settings.domains.home}";
      keyFile = config.age.secrets.bitwarden-key.path;
    };
    fish.enable = true;
    fzf.enable = true;
    gh.enable = true;
    git = {
      enable = true;
      sshKey.pub = ../../keys/ssh.pub;
      user.name = private-settings.git.charlotte.name;
      user.email = private-settings.git.charlotte.email;
    };
    nix-your-shell.enable = true;
  };
  age.secrets.bitwarden-key.rekeyFile = secrets.charlotte-bitwarden-pass;

  programs.ssh = {
    matchBlocks = {
      gsv = {
        hostname = gsv.ip;
        user = gsv.user;
        port = gsv.port;
      };
      gsv-boot = {
        hostname = gsv.ip;
        user = gsv.user;
        port = gsv.port-boot;
      };
      rmpp = {
        hostname = "192.168.50.130";
        user = "root";
      };
      "*".identityFile = lib.mkForce [
        "~/.ssh/id_yubikey"
        "~/.ssh/id_charlotte"
      ];
    };
  };

  home.file = {
    ".ssh/id_ed25519.pub".source = ../../keys/ssh.pub;
    ".ssh/id_charlotte.pub".source = ../../keys/ssh.pub;
  };
  home.activation = {
    linkSshKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      [ -f ${config.age.secrets.charlotte-ssh.path} ] || exit 0
      ln -sf ${config.age.secrets.charlotte-ssh.path} ${config.home.homeDirectory}/.ssh/id_charlotte
      chmod 600 ${config.home.homeDirectory}/.ssh/id_charlotte
    '';
  };
}
