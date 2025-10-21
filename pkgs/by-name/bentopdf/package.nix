{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage (finalAttrs: {
  version = "1.1.5";
  pname = "bentopdf";

  src = fetchFromGitHub {
    owner = "alam00000";
    repo = "bentopdf";
    tag = "v${finalAttrs.version}";
    hash = "sha256-4MTd4Ve0bwIj9RMk3jh8Cg6X95mOblLaElxCDPL/lmQ=";
  };
  npmDepsHash = "sha256-mno/h+hZwkGDFgi+qZoqRYXlSKbqFAv7XPJ6QPlYSZ4=";

  npmBuildScript = "build";
  npmBuildFlags = [
    "--"
    "--mode"
    "production"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r dist/* $out/

    runHook postInstall
  '';

  passthru.tests.simple = finalAttrs.finalPackage.overrideAttrs { SIMPLE_MODE = "true"; };

  meta = with lib; {
    description = "A Privacy First PDF Toolkit";
    mainProgram = "bentopdf";
    homepage = "https://bentopdf.com";
    license = licenses.agpl3Only;
    maintainers = with maintainers; [ charludo ];
  };
})
