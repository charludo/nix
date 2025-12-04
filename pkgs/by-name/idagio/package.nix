{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  makeWrapper,
  clang,
  llvm,
  llvmPackages,
  lld,
}:
rustPlatform.buildRustPackage rec {
  name = "idagio";
  src = fetchFromGitHub {
    owner = "charludo";
    repo = "IDAGIO-Downloader-Rust-ver";
    rev = "eaaae3168b65bfb10b6657d950df0ee93f1363b5";
    sha256 = "sha256-/fJ1RYbbmp42dtlcIgDgjULXiiQXgi/5XOKu1VSP09E=";
  };
  cargoLock.lockFile = "${src}/Cargo.lock";

  buildInputs = [
    pkg-config
    openssl
    makeWrapper
  ];
  nativeBuildInputs = [
    clang
    llvm
    llvmPackages.libclang
    lld
    pkg-config
    openssl
  ];
  LD_LIBRARY_PATH = lib.makeLibraryPath buildInputs;
  propagatedBuildInputs = [ openssl ];
  postInstall = ''
    wrapProgram $out/bin/${name} \
      --set LD_LIBRARY_PATH ${openssl.out}/lib
  '';

  meta.mainProgram = "idagio";
}
