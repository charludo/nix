{
  age,
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
    openssh

    # used by nix fmt
    nixfmt-rfc-style
    deadnix
    ruff
  ];
}
