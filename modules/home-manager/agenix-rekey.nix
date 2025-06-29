{ config, lib, ... }:
let
  cfg = config.agenix-rekey;
in
{
  options.agenix-rekey.pubkey = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    description = "set agenix-rekey primary (and only) identity";
  };

  config = lib.mkIf (cfg.pubkey != null) {
    programs.fish.interactiveShellInit = # fish
      ''
        set -gx AGENIX_REKEY_PRIMARY_IDENTITY "${builtins.readFile cfg.pubkey}"
        set -gx AGENIX_REKEY_PRIMARY_IDENTITY_ONLY true
      '';
  };
}
