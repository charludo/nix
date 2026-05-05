{ python3Packages, ... }:
python3Packages.buildPythonApplication {
  pname = "hass-grocery-categorize";
  version = "0.1.0";
  pyproject = true;
  src = ../../../hass-grocery-categorize;

  build-system = [ python3Packages.setuptools ];

  dependencies = with python3Packages; [
    sentence-transformers
    numpy
    rapidfuzz
  ];

  # No upstream tests in the package; the repo's own pytest suite uses
  # mocked deps and runs in dev environments. Skipping in-build tests
  # keeps the closure small.
  doCheck = false;
}
