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
  imports = [
    ../../../../common/ssh.nix
  ];
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
      "*".identityFile = [
        "~/.ssh/id_charlotte"
      ];
    };

    extraConfig = ''
      AddKeysToAgent yes
    '';
  };

  age.secrets.charlotte-ssh.rekeyFile = secrets.charlotte-ssh;
  home.activation = {
    linkSshKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ln -sf ${config.age.secrets.charlotte-ssh.path} ${config.home.homeDirectory}/.ssh/id_charlotte
      chmod 600 ${config.home.homeDirectory}/.ssh/id_charlotte
    '';
  };
  home.file = {
    ".ssh/id_ed25519.pub".source = ../../../ssh.pub;
    ".ssh/id_charlotte.pub".source = ../../../ssh.pub;
  };
}
