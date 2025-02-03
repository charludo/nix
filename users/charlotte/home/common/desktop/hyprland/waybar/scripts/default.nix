{
  pkgs,
  config,
  private-settings,
  secrets,
  ...
}:
{
  home.packages = [
    (import ./playerctl.nix { inherit pkgs; })
    (import ./wireguard.nix { inherit pkgs; })
    (import ./lemmy.nix {
      inherit config;
      inherit pkgs;
      inherit private-settings;
    })
    (import ./reddit.nix {
      inherit config;
      inherit pkgs;
    })
    (import ./mail.nix {
      inherit config;
      inherit pkgs;
    })
  ];

  age.secrets.lemmy-username.rekeyFile = secrets.charlotte-lemmy-username;
  age.secrets.lemmy-password.rekeyFile = secrets.charlotte-lemmy-password;
  age.secrets.reddit-username.rekeyFile = secrets.charlotte-reddit-username;
  age.secrets.reddit-token.rekeyFile = secrets.charlotte-reddit-token;
  age.secrets.waybar-mail.rekeyFile = secrets.charlotte-waybar-mail;
}
