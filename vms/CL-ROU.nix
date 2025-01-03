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

    networking.openPorts.tcp = [ 8000 ];
    networking.openPorts.udp = [ 8000 ];
  };

  programs.fish.enable = true;
  users.defaultUserShell = pkgs.fish;

  system.stateVersion = "23.11";
}
