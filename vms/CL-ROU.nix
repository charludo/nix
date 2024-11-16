{ pkgs, ... }:
{
  imports = [
    ./_common.nix
    ../users/charlotte/user.nix
  ];

  vm = {
    id = 3022;
    name = "CL-ROU";

    hardware.cores = 8;
    hardware.memory = 16284;
    hardware.storage = "16G";

    networking.address = "192.168.30.97";
    networking.gateway = "192.168.30.1";
    networking.prefixLength = 24;

    networking.openPorts.tcp = [ 8000 ];
    networking.openPorts.udp = [ 8000 ];
  };

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  system.stateVersion = "23.11";
}
