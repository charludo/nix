{ writers, python3Packages }:
writers.writePython3Bin "zha-reconciler" {
  libraries = [ python3Packages.aiohttp ];
  flakeIgnore = [
    "E501"
    "E402"
  ];
} (builtins.readFile ./zha_reconciler.py)
