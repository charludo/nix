{ lib, private-settings, ... }:
{
  imports = [
    ./locale.nix
    ./nix.nix
    ./nixpkgs.nix
    ./openssh.nix
    ./shell.nix
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

  # Same list as nixos/modules/security/ca.nix (NixOS/nixpkgs#576485).
  # Remove on next nixpkgs bump.
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
    "emSign ECC Root CA - G3"
    "emSign Root CA - C1"
    "emSign ECC Root CA - C3"
  ];
}
