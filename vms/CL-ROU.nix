{
  inputs,
  outputs,
  lib,
  pkgs,
  private-settings,
  secrets,
  ...
}:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ../users/charlotte/user.nix
  ];

  home-manager.users.charlotte.imports = [
    inputs.agenix.homeManagerModules.default
    inputs.agenix-rekey.homeManagerModules.default
    inputs.nix-colors.homeManagerModules.colorScheme
    inputs.nixvim.homeModules.nixvim
  ]
  ++ (builtins.attrValues outputs.homeModules);
  home-manager.extraSpecialArgs = {
    inherit
      inputs
      outputs
      lib
      pkgs
      private-settings
      secrets
      ;
  };

  vm = {
    id = 3022;
    name = "CL-ROU";

    hardware.cores = 6;
    hardware.memory = 16284;
    hardware.storage = "16G";

    networking.openPorts.tcp = [ 8000 ];
    networking.openPorts.udp = [ 8000 ];
  };

  ld.enable = true;
  programs.dconf.enable = true;
  yubikey.enable = false;
}
