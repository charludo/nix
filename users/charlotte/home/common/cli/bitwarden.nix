{ config, pkgs, private-settings, ... }:
let
  pinentry-fake = pkgs.writeShellApplication {
    name = "pinentry-fake";
    runtimeInputs = [ pkgs.bat ];
    text = ''
      echo "D $(cat ${config.sops.secrets."bitwarden/pass".path})"
      echo "OK"
    '';
  };
  rbw-unlock = pkgs.writeShellApplication {
    name = "rbw-unlock";
    runtimeInputs = [ pkgs.bat pkgs.rbw pinentry-fake ];
    text = ''
      rbw config set pinentry "pinentry-fake"
      rbw config set email "$(cat ${config.sops.secrets."bitwarden/mail".path})"
      rbw config set base_url "https://passwords.${private-settings.domains.home}"
      rbw unlock
    '';
  };

in
{
  # We do this rather than using programs.rbw.enable
  # because the login script needs to be able to edit the config file
  home.packages = [ pkgs.rbw rbw-unlock ];

  sops.secrets."bitwarden/mail" = { };
  sops.secrets."bitwarden/pass" = { };
}
