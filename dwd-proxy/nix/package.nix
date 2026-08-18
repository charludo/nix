{
  lib,
  buildGoModule,
  version,
}:
buildGoModule {
  pname = "dwd-proxy";
  inherit version;

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../go.mod
      ../go.sum
      (lib.fileset.fileFilter (file: lib.hasSuffix ".go" file.name) ../.)
    ];
  };

  vendorHash = "sha256-/YHgnvq9X/GSqdBARKdwziT21eDk2vRohccs0BlIPHQ=";

  subPackages = [ "." ];
  env.CGO_ENABLED = 0;
  ldflags = [
    "-s"
    "-X main.version=v${version}"
  ];

  # The race detector needs cgo.
  preCheck = "export CGO_ENABLED=1";
  checkPhase = ''
    runHook preCheck
    go test -race ./...
    runHook postCheck
  '';

  meta = {
    description = "Caching proxy and prefetcher for the DWD radar WMS service";
    license = lib.licenses.mit;
    mainProgram = "dwd-proxy";
  };
}
