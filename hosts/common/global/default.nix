{ inputs, outputs, pkgs, ... }: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ./locale.nix
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
    ln -s /run/current-system/sw/bin/bash /bin/bash
  '';
}
