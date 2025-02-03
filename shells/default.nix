{ pkgs, ... }:
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    age
    openssh

    # used by nix fmt
    nixfmt-rfc-style
    deadnix
    ruff
  ];
}
