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
    inputs.plasma-manager.homeModules.plasma-manager
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

  soundConfig.enable = true;

  users.mutableUsers = lib.mkForce true;

  vm = {
    id = 3020;
    name = "CL-NIX-3";

    hardware.cores = 4;
    hardware.memory = 4096;
    hardware.storage = "8G";

    networking = {
      address = "192.168.130.99";
      gateway = "192.168.130.1";
      nameservers = private-settings.upstreamDNS.ips;
      prefixLength = 24;
    };
  };

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    plasma-browser-integration
  ];

  services.xrdp = {
    enable = true;
    defaultWindowManager = "startplasma-x11";
    openFirewall = true;
  };
}
