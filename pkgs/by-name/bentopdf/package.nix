{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage (finalAttrs: {
  version = "1.7.9";
  pname = "bentopdf";

  src = fetchFromGitHub {
    owner = "alam00000";
    repo = "bentopdf";
    tag = "v${finalAttrs.version}";
    hash = "sha256-vSwjQWwxjYMjFIt30BqwaMo4M9hrjFLTNVwtObwOHkI=";
  };
  npmDepsHash = "sha256-rGafLfp+RzR8x8iFIDactIv+bVPEo9XH0l0eJc31JkE=";

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
