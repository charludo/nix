{ writers }:
writers.writePython3Bin "papra-imap-relay" {
  flakeIgnore = [ "E501" ];
} (builtins.readFile ./papra_imap_relay.py)
