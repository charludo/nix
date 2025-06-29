{
  pkgs,
  config,
  private-settings,
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
    (import ./calendar.nix {
      inherit config;
      inherit pkgs;
    })
  ];
}
