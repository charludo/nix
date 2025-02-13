{
  pkgs,
  inputs,
  outputs,
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
    inputs.nixvim.homeManagerModules.nixvim
  ] ++ (builtins.attrValues outputs.homeModules);
  home-manager.extraSpecialArgs = {
    inherit
      inputs
      outputs
      private-settings
      secrets
      ;
  };

  vm = {
    id = 3022;
    name = "CL-ROU";

    hardware.cores = 8;
    hardware.memory = 16284;
    hardware.storage = "16G";

    networking.openPorts.tcp = [ 8000 ];
    networking.openPorts.udp = [ 8000 ];
    runOnSecondHost = true;
  };

  ld.enable = true;
  programs.fish.enable = true;
  users.defaultUserShell = pkgs.fish;
  snow.enable = true;

  system.stateVersion = "23.11";
}
