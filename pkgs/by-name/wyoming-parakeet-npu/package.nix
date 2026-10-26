{
  lib,
  fetchFromGitHub,
  addDriverRunpath,
  python3Packages,
}:
python3Packages.buildPythonApplication {
  pname = "wyoming-parakeet-npu";
  version = "0.1.0-unstable-2026-05-25";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "cibernox";
    repo = "wyoming-parakeet-on-intel-npu";
    rev = "238b52b0c47346295599417abe53ea02e2343f59";
    hash = "sha256-C6yXVBoZhgY6Yj6y83Lsy0MlCHDtJ8EXddfRLFNNwhk=";
  };

  # Model repo selectable via HF_REPO (e.g. Parakeet Ultra), with v3 as the
  # fallback for files an export lacks.
  patches = [ ./bootstrap-hf-repo.patch ];

  build-system = with python3Packages; [
    setuptools
    wheel
  ];

  dependencies = with python3Packages; [
    huggingface-hub
    numpy
    onnx-asr
    onnxruntime
    openvino
    soundfile
    wyoming
  ];

  # Upstream pins exact versions for its Docker image.
  pythonRelaxDeps = [
    "onnxruntime"
    "wyoming"
  ];
  # nixpkgs installs openvino without dist-info metadata.
  pythonRemoveDeps = [ "openvino" ];

  # The bootstrap (download missing model files, build the static decoder
  # IR) is a separate script upstream, run by its Docker entrypoint.
  # Upstream calls it with an explicit `python`, so it has no shebang; add one
  # so wrapPythonPrograms gives it the package's environment.
  postInstall = ''
    { echo '#!/usr/bin/env python3'; cat scripts/bootstrap.py; } > $out/bin/wyoming-parakeet-npu-bootstrap
    chmod +x $out/bin/wyoming-parakeet-npu-bootstrap

    # The declared entry point calls the async main() without running it;
    # upstream's image starts `python -m wyoming_parakeet_npu` instead.
    cat > $out/bin/wyoming-parakeet-npu <<'EOF'
    #!/usr/bin/env python3
    import asyncio

    from wyoming_parakeet_npu.__main__ import main

    asyncio.run(main())
    EOF
    sed -i 's/^    //' $out/bin/wyoming-parakeet-npu
  '';

  makeWrapperArgs = [
    # OpenVINO's NPU plugin dlopens the Level Zero loader, which finds the
    # NPU driver and compiler (hardware.graphics on NixOS).
    "--prefix"
    "LD_LIBRARY_PATH"
    ":"
    "${addDriverRunpath.driverLink}/lib"
  ];

  pythonImportsCheck = [
    "wyoming_parakeet_npu"
    "openvino"
    "onnx_asr"
  ];

  meta = {
    description = "Wyoming speech-to-text server running Parakeet TDT on the Intel NPU via OpenVINO";
    homepage = "https://github.com/cibernox/wyoming-parakeet-on-intel-npu";
    license = lib.licenses.mit;
    mainProgram = "wyoming-parakeet-npu";
  };
}
