# Include this file to be able to build images from any configuration using
# nix build .#nixosConfigurations.<hostname>.config.formats.<format>
{ inputs, ... }:
{
  imports = [
    inputs.nixos-generators.nixosModules.all-formats
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  services.qemuGuest.enable = true;

  formatConfigs.qcow-efi = { config, ... }: {
    services.openssh.enable = true;
  };
}
