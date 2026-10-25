{
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  wheel,
}:
buildPythonPackage rec {
  pname = "pymicro-features";
  version = "2.0.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "rhasspy";
    repo = "pymicro-features";
    tag = "v${version}";
    hash = "sha256-bCvrsvifUxM7jfqBePmcYviZ5pIy1ZApq48Pu/5b7AM=";
  };

  build-system = [
    setuptools
    wheel
  ];

  pythonImportsCheck = [ "pymicro_features" ];
}
