{
  autoPatchelfHook,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  numpy,
  pymicro-features,
}:
buildPythonPackage rec {
  pname = "pymicro-wakeword";
  version = "2.4.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "OHF-Voice";
    repo = "pymicro-wakeword";
    tag = "v${version}";
    hash = "sha256-R8uAKJygh5mo8U9k0uT358RMxJnezRxAATjjaK4D9PI=";
  };

  # Picks the vendored prebuilt libtensorflowlite_c for the build platform
  # (same approach as nixpkgs' pyopen-wakeword).
  postPatch = ''
    python ./script/copy_lib
  '';

  nativeBuildInputs = [ autoPatchelfHook ];

  build-system = [ setuptools ];

  dependencies = [
    numpy
    pymicro-features
  ];

  pythonImportsCheck = [ "pymicro_wakeword" ];
}
