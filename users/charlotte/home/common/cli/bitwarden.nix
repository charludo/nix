{
  config,
  pkgs,
  private-settings,
  secrets,
  ...
}:
let
  pinentry-fake = pkgs.writeShellApplication {
    name = "pinentry-fake";
    runtimeInputs = [ pkgs.bat ];
    text = ''
      # shellcheck disable=SC2086
      echo "D $(gpg --quiet --decrypt ${config.age.secrets.bitwarden-pass.path} 2>/dev/null)"
      echo "OK"
    '';
  };
in
{
  age.secrets.bitwarden-pass.rekeyFile = secrets.charlotte-bitwarden-pass;

  programs.rbw = {
    enable = true;
    settings = {
      pinentry = pinentry-fake;
      email = "${private-settings.email.vaultwarden}";
      base_url = "https://passwords.${private-settings.domains.home}";
    };
  };
}
