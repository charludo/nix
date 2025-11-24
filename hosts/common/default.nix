{ lib, private-settings, ... }:
{
  imports = [
    ./locale.nix
    ./nix.nix
    ./nixpkgs.nix
    ./openssh.nix
  ];

  age.enable = true;
  users.mutableUsers = false;

  console.keyMap = lib.mkDefault "us-acentos";
  security.pki.certificateFiles = [ private-settings.caIssuing1.root ];
  networking.domain = lib.mkDefault private-settings.domains.ad;
  networking.search = [ private-settings.domains.ad ];

  system.activationScripts.script.text = ''
    ln -sf /run/current-system/sw/bin/bash /bin/bash
  '';

  system.stateVersion = lib.mkDefault "23.11";
}
