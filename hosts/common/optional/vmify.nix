# Include this file to be able to build images from any configuration using
# nix build .#nixosConfigurations.<hostname>.config.formats.<format>
{ inputs, ... }:
{
  imports = [
    inputs.nixos-generators.nixosModules.all-formats
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  formatConfigs.qcow-efi = { config, lib, ... }: {
    services.qemuGuest.enable = lib.mkForce true;
    services.openssh.enable = lib.mkForce true;
  };

  formatConfigs.install-iso = { config, lib, pkgs, ... }: {
    boot.loader.grub.enable = lib.mkForce false;
    boot.loader.systemd-boot.enable = lib.mkForce false;
    networking.networkmanager.enable = lib.mkForce false;
    services.openssh.settings = {
      PasswordAuthentication = lib.mkForce true;
      PermitRootLogin = lib.mkForce "yes";
    };
    environment.systemPackages = [ pkgs.nixos-install-tools ];
  };

  formatConfigs.iso = { config, lib, ... }: {
    boot.loader.grub.enable = lib.mkForce false;
    boot.loader.systemd-boot.enable = lib.mkForce false;
  };
}
