{
  haskellPackages,
  fetchgit,
}:

haskellPackages.callCabal2nix "nixpkgs-bot" (
  fetchgit {
    url = "https://code.maralorn.de/maralorn/config.git";
    rev = "0b57faa34d2f31e5bd7091780192c8d855b1b349";
    sha256 = "sha256-YmS328MZ9mK2hErMnsc2LnWwrfV1sp9nirLJDB/AA2U=";
  }
  + "/packages/nixpkgs-bot"
) { }
