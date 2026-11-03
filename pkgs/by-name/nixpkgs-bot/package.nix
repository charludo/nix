{
  haskellPackages,
  haskell,
  fetchgit,
}:

haskell.lib.appendPatches
  (
    (haskellPackages.extend (
      _: prev: {
        # test suite pulls in mysql-simple -> pcre-light, which needs the removed pcre library
        esqueleto = haskell.lib.dontCheck prev.esqueleto;

        # continuwuity omits "timeline" in /sync for rooms without timeline updates
        matrix-client = haskell.lib.appendPatch prev.matrix-client ./matrix-client-optional-timeline.patch;
      }
    )).callCabal2nix
      "nixpkgs-bot"
      (
        fetchgit {
          url = "https://code.maralorn.de/maralorn/config.git";
          rev = "13f6652b1a822969293c56309043f8f19f7f4a04";
          sha256 = "sha256-COBLxUMSbBW39d8N4v1OlKOyz15Lo1VCZJ1bPrfL3+M=";
        }
        + "/packages/nixpkgs-bot"
      )
      { }
  )
  [
    ./lag-merge-lookups.patch
    ./approval-subscriptions.patch
  ]
