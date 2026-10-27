{
  fetchFromGitHub,
  iproute2,
  lib,
  python3Packages,
  which,
  ...
}:
let
  pymicro-features = python3Packages.callPackage ./pymicro-features.nix { };
  pymicro-wakeword = python3Packages.callPackage ./pymicro-wakeword.nix { inherit pymicro-features; };
  # nixpkgs marks this broken on aarch64 (its vendored libtensorflowlite_c
  # segfaults there), but LVA imports it unconditionally. Unbroken so LVA
  # can at least start; only openWakeWord models call into it, so stick to
  # microWakeWord models on the Pi until that's verified.
  pyopen-wakeword = python3Packages.pyopen-wakeword.overridePythonAttrs (old: {
    doCheck = false;
    meta = old.meta // {
      broken = false;
    };
  });
in
python3Packages.buildPythonApplication rec {
  pname = "linux-voice-assistant";
  version = "1.1.15";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "OHF-Voice";
    repo = "linux-voice-assistant";
    tag = "v${version}";
    hash = "sha256-n/d5+hwivoInpjrx5Wnv7WGPnyH9xmXFLD4Nvdc3M5A=";
  };

  build-system = with python3Packages; [
    setuptools
    setuptools-scm
  ];

  # Name the wake word in the peripheral API's `wake_word_detected` event;
  # upstream sends it without data. Used by the activation log.
  patches = [ ./wake-word-event-data.patch ];

  # The version is meant to come from git (setuptools-scm) for the package
  # metadata and from version.txt (written by upstream's Docker build) at
  # runtime; neither exists in a source tarball.
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'dynamic = ["version"]' 'version = "${version}"'
    echo ${version} > version.txt
  '';

  # Upstream pins exact versions; nixpkgs is ahead on both.
  pythonRelaxDeps = [
    "aioesphomeapi"
    "websockets"
  ];
  # Provided by nixpkgs' `mpv`, whose dist name differs.
  pythonRemoveDeps = [ "python-mpv" ];

  dependencies =
    with python3Packages;
    [
      aioesphomeapi
      getmac
      mpv # PyPI name: python-mpv
      netifaces2
      numpy
      soundcard
      types-protobuf
      webrtc-noise-gain
      websockets
      zeroconf
    ]
    ++ [
      pymicro-wakeword
      pyopen-wakeword
    ];

  # netifaces2 finds the default gateway by running `which ip` and `ip`.
  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [
      iproute2
      which
    ])
  ];

  # Default wake word and sound directories resolve to the module's parent
  # (site-packages here), but the wheel doesn't ship them.
  postInstall = ''
    cp -r wakewords sounds version.txt $out/${python3Packages.python.sitePackages}/
  '';

  pythonImportsCheck = [ "linux_voice_assistant" ];

  passthru = { inherit pymicro-features pymicro-wakeword; };

  meta.mainProgram = "linux-voice-assistant";
}
