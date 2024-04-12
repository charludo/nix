{ inputs, outputs, pkgs, ... }: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ./auto-update.nix
    ./locale.nix
    ./nas.nix
    ./nix.nix
    ./openssh.nix
    ./sops.nix
  ] ++ (builtins.attrValues outputs.nixosModules);

  home-manager.extraSpecialArgs = { inherit inputs outputs; };
  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays;
    config = {
      allowUnfree = true;
    };
  };

  users.mutableUsers = false;

  console.keyMap = "us-acentos";
  networking.domain = "ad.paki.place";

  environment.systemPackages = with pkgs; [
    jq
    gcc
    unzip
    ripgrep
    killall
  ];

  system.activationScripts.script.text = ''
    ln -sf /run/current-system/sw/bin/bash /bin/bash
  '';
}
