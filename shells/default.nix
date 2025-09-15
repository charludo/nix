{
  age,
  agenix-rekey,
  openssh,
  nixfmt-rfc-style,
  deadnix,
  ruff,
  mkShell,
  ...
}:
mkShell {
  nativeBuildInputs = [
    age
    agenix-rekey
    openssh

    # used by nix fmt
    nixfmt-rfc-style
    deadnix
    ruff
  ];
}
