{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  tbb,
  zlib,
  zstd,
}:
# The NPU driver's graph compiler ("compiler in driver"). nixpkgs'
# intel-npu-driver builds only the Level Zero driver (libze_intel_npu), which
# loads this library to turn models into NPU code; without it every compile
# fails with ZE_RESULT_ERROR_UNSUPPORTED_FEATURE. Intel publishes it only as a
# binary in its driver releases. Keep the version in step with
# intel-npu-driver.
stdenv.mkDerivation rec {
  pname = "intel-npu-compiler";
  version = "1.38.0";
  build = "20260910-34487311128";

  src = fetchurl {
    url = "https://github.com/intel/linux-npu-driver/releases/download/v${version}/linux-npu-driver-v${version}.${build}-ubuntu2604.tar.gz";
    hash = "sha256-g2hebZL02xymXkQoRtSHx/6xM1Y0szmUKSzrOPkzvMc=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    tbb
    zlib
    zstd
  ];

  unpackPhase = ''
    tar xzf $src
    dpkg-deb -x intel-driver-compiler-npu_${version}.${build}~ubuntu26.04_amd64.deb root
  '';

  installPhase = ''
    install -Dm755 -t $out/lib root/usr/lib/x86_64-linux-gnu/libopenvino_intel_npu_compiler*.so
  '';

  meta = {
    description = "Intel NPU graph compiler (compiler in driver) from Intel's NPU driver releases";
    homepage = "https://github.com/intel/linux-npu-driver";
    # Built from openvinotoolkit/npu_compiler (Apache-2.0).
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
