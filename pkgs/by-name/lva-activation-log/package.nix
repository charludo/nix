{ python3Packages, writers }:
# Needs `pw-record` (pipewire) on PATH; the NixOS module provides it.
writers.writePython3Bin "lva-activation-log" {
  libraries = [ python3Packages.websockets ];
  flakeIgnore = [ "E501" ];
} (builtins.readFile ./lva_activation_log.py)
