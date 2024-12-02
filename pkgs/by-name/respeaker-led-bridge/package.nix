{ python3Packages, ... }:
python3Packages.buildPythonApplication {
  pname = "respeaker-led-bridge";
  version = "0.1.0";
  pyproject = true;
  src = ./.;

  build-system = [ python3Packages.setuptools ];

  dependencies = with python3Packages; [
    aiohttp
    pixel-ring
    pyusb
    wyoming
  ];

  doCheck = false;
}
