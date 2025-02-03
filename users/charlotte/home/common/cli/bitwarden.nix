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
      echo "D $(cat ${config.age.secrets.bitwarden-pass.path})"
      echo "OK"
    '';
  };
  rbw-unlock = pkgs.writeShellApplication {
    name = "rbw-unlock";
    runtimeInputs = [
      pkgs.bat
      pkgs.rbw
      pinentry-fake
    ];
    text = ''
      rbw config set pinentry "pinentry-fake"
      # shellcheck disable=SC2086
      rbw config set email "$(cat ${config.age.secrets.bitwarden-mail.path})"
      rbw config set base_url "https://passwords.${private-settings.domains.home}"
      rbw unlock
    '';
  };

in
{
  # We do this rather than using programs.rbw.enable
  # because the login script needs to be able to edit the config file
  home.packages = [
    pkgs.rbw
    rbw-unlock
  ];

  age.secrets.bitwarden-mail.rekeyFile = secrets.charlotte-bitwarden-mail;
  age.secrets.bitwarden-pass.rekeyFile = secrets.charlotte-bitwarden-pass;
}
