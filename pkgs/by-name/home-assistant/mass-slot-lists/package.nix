{ writers, python3Packages }:
writers.writePython3Bin "mass-slot-lists" {
  libraries = with python3Packages; [
    aiohttp
    pyyaml
    music-assistant-client
  ];
  flakeIgnore = [
    "E501"
    "E402"
  ];
} (builtins.readFile ./mass_slot_lists.py)
