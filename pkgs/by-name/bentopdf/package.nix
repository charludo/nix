{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage (finalAttrs: {
  version = "1.0.2";
  pname = "bentopdf";

  src = fetchFromGitHub {
    owner = "alam00000";
    repo = "bentopdf";
    rev = "v${finalAttrs.version}";
    hash = "sha256-lQeh7LhHnvT4ZaQHoxRm8kpVAmCoKBg3h6JpJyTjmcY=";
  };
  npmDepsHash = "sha256-8hXYeDaoKWv5zFxEbFF3vua/2O9sw+0HGckzIys5AVA=";

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

  passthru = {
    # The "simple" variant contains the same functionality, but no branding/marketing.
    simple =
      with finalAttrs;
      buildNpmPackage {
        inherit
          version
          pname
          src
          npmDepsHash
          npmBuildScript
          npmBuildFlags
          installPhase
          ;
        SIMPLE_MODE = "true";
      };
  };

  meta = with lib; {
    description = "A Privacy First PDF Toolkit";
    mainProgram = "bentopdf";
    homepage = "https://bentopdf.com";
    license = licenses.asl20;
    maintainers = with maintainers; [ charludo ];
  };
})
