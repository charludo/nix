{
  lib,
  haskell,
  haskellPackages,
  fetchFromGitHub,
  tzdata,
}:
let
  inherit (haskell.lib.compose)
    overrideSrc
    doJailbreak
    markUnbroken
    justStaticExecutables
    appendPatches
    overrideCabal
    ;
in
# Facebook's parser for times, durations and numbers in text, as an HTTP
# server (`duckling-example-exe`). The Hackage release (2020) in nixpkgs is
# broken; master builds with its version bounds relaxed and two patches.
lib.pipe haskellPackages.duckling [
  # nixpkgs dropped pcre (v1), which regex-pcre links against; take the
  # variant with the C library bundled, as duckling does on Windows.
  (drv: drv.override { regex-pcre = haskellPackages.regex-pcre-builtin; })
  (overrideSrc {
    version = "0.2.0.1-unstable-2026-03-15";
    src = fetchFromGitHub {
      owner = "facebook";
      repo = "duckling";
      rev = "59a13ff87b1aa8be6b93d387244f8636b26185c5";
      hash = "sha256-/oxkx8ES5Tz2pmV2lYNXUjkEwdaCN+gdzqSIMatCUsg=";
    };
  })
  (appendPatches [
    # Text has been UTF-8 inside since text 2: cut matches out by UTF-8
    # offsets instead of the removed UTF-16 ones.
    ./text-2.patch
    # German: "anderthalb Stunden", "zweieinhalb Minuten",
    # "zwei Stunden und eine halbe".
    ./de-and-a-half.patch
  ])
  doJailbreak
  markUnbroken
  # Just the server: the library would pull in GHC.
  justStaticExecutables
  (overrideCabal (drv: {
    # Before jailbreak-cabal drops the version bounds this matches on.
    prePatch = (drv.prePatch or "") + ''
      substituteInPlace duckling.cabal \
        --replace-fail 'regex-pcre              >=' 'regex-pcre-builtin      >='
    '';
    # The server reads time zones from /usr/share/zoneinfo, which NixOS
    # (and the build sandbox) doesn't have.
    postPatch = (drv.postPatch or "") + ''
      substituteInPlace exe/ExampleMain.hs \
        --replace-fail '"/usr/share/zoneinfo/"' '"${tzdata}/share/zoneinfo/"'
    '';
    postInstall = (drv.postInstall or "") + ''
      find $out/bin -type f ! -name duckling-example-exe -delete
    '';
  }))
]
