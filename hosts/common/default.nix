{
  inputs,
  outputs,
  pkgs,
  private-settings,
  ...
}:
{
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

  users.mutableUsers = false;

  console.keyMap = "us-acentos";
  networking.domain = private-settings.domains.ad;

  environment.systemPackages = with pkgs; [
    jq
    gcc
    unzip
    ripgrep
    killall
    wget
  ];

  system.activationScripts.script.text = ''
    ln -sf /run/current-system/sw/bin/bash /bin/bash
  '';
}
