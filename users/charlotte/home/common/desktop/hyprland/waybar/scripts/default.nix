{ pkgs, config, ... }:
{
  home.packages = [
    (import ./playerctl.nix { inherit pkgs; })
    (import ./wireguard.nix { inherit pkgs; })
    (import ./reddit.nix { inherit config; inherit pkgs; })
    (import ./mail.nix { inherit config; inherit pkgs; })
  ];

  sops.secrets."reddit/username" = { };
  sops.secrets."reddit/token" = { };
  sops.secrets.waybar-mail = { };
}
