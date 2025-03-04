{ private-settings, ... }:
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
    };

    extraConfig = ''
      AddKeysToAgent yes
    '';
  };

  home.file = {
    ".ssh/id_ed25519.pub".source = ../../../ssh.pub;
  };
}
