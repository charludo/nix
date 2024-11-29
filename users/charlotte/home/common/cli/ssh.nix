{ inputs, ... }:
let
  inherit (inputs.private-settings) gsv;
in
{
  imports = [
    ../../../../common/ssh.nix
  ];
  programs.ssh = {
    matchBlocks = {
      gsv = { hostname = gsv.ip; user = gsv.user; port = gsv.port; };
      gsv-boot = { hostname = gsv.ip; user = gsv.user; port = gsv.port-boot; };
    };
  };
}
