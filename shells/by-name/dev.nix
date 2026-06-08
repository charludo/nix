{
  age,
  agenix-rekey,
  openssh,
  mkShell,
  ...
}:
mkShell {
  nativeBuildInputs = [
    age
    agenix-rekey
    openssh
  ];
}
