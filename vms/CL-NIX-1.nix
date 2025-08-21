{
  lib,
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
    ../users/marie/user.nix
  ];

  home-manager.users.marie.imports = [
    inputs.agenix.homeManagerModules.default
    inputs.agenix-rekey.homeManagerModules.default
    inputs.nix-colors.homeManagerModules.colorScheme
    inputs.nixvim.homeModules.nixvim
    inputs.plasma-manager.homeManagerModules.plasma-manager
  ]
  ++ (builtins.attrValues outputs.homeModules);
  home-manager.extraSpecialArgs = {
    inherit
      inputs
      outputs
      private-settings
      secrets
      ;
  };

  soundConfig.enable = true;

  users.mutableUsers = lib.mkForce true;
  nas.backup.enable = true;
  snow.enable = true;

  vm = {
    id = 3020;
    name = "CL-NIX-1";

    hardware.cores = 4;
    hardware.memory = 4096;
    hardware.storage = "64G";
  };

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;

  environment.plasma5.excludePackages = with pkgs.libsForQt5; [
    plasma-browser-integration
  ];

  services.xrdp = {
    enable = true;
    defaultWindowManager = "startplasma-x11";
    openFirewall = true;
  };

  system.stateVersion = "23.11";
}
