{
  age,
  agenix-rekey,
  openssh,
  nixfmt,
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
    nixfmt
    deadnix
    ruff
  ];
}
