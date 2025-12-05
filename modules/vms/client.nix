{
  inputs,
  outputs,
  config,
  lib,
  pkgs,
  private-settings,
  secrets,
  ...
}:
let
  cfg = config.vm.clientDevice;
in
{
  options.vm.clientDevice.enable = lib.mkEnableOption "required settings for turning the device into a home-manager enabled client device";
  options.vm.clientDevice.kde = lib.mkEnableOption "a KDE-based desktop";

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {

      home-manager.sharedModules = [
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

    })
    (lib.mkIf (cfg.enable && cfg.kde) {
      # allow to edit password imperatively
      users.mutableUsers = lib.mkForce true;

      soundConfig.enable = true;

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
    })
  ];
}
