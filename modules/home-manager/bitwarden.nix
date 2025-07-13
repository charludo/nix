{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cli.bitwarden;
in
{
  options.cli.bitwarden.enable = lib.mkEnableOption "rbw bitwarden client";
  options.cli.bitwarden.keyFile = lib.mkOption {
    type = lib.types.path;
    description = "path to file containing the bitwarden key/password";
  };
  options.cli.bitwarden.email = lib.mkOption {
    type = lib.types.str;
    description = "email address used for login to bitwarden";
  };
  options.cli.bitwarden.url = lib.mkOption {
    type = lib.types.str;
    description = "URL of the self-hosted bitwarden/vaultwarden instance";
  };

  config =
    let
      pinentry-fake = pkgs.writeShellApplication {
        name = "pinentry-fake";
        runtimeInputs = [
          pkgs.bat
          pkgs.gnupg
        ];
        text = # bash
          ''
            # shellcheck disable=SC2086
            echo "D $(gpg --quiet --decrypt ${cfg.keyFile} 2>/dev/null)"
            echo "OK"
          '';
      };
    in
    lib.mkIf cfg.enable {
      programs.rbw = {
        enable = true;
        settings = {
          pinentry = pinentry-fake;
          email = cfg.email;
          base_url = cfg.url;
        };
      };
    };
}
