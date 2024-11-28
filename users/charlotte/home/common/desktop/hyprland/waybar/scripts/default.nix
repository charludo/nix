{ pkgs, config, inputs, ... }:
{
  home.packages = [
    (import ./playerctl.nix { inherit pkgs; })
    (import ./wireguard.nix { inherit pkgs; })
    (import ./lemmy.nix { inherit config; inherit pkgs; inherit inputs; })
    (import ./reddit.nix { inherit config; inherit pkgs; })
    (import ./mail.nix { inherit config; inherit pkgs; })
  ];

  sops.secrets."lemmy/username" = { };
  sops.secrets."lemmy/password" = { };
  sops.secrets."reddit/username" = { };
  sops.secrets."reddit/token" = { };
  sops.secrets.waybar-mail = { };
}
