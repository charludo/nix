{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop.discord;
in
{
  options.desktop.discord.enable = lib.mkEnableOption "Discord client";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      discord
    ];
    home.file.".config/discord/settings.json" = {
      text = ''
        {
        "SKIP_HOST_UPDATE": true
        }
      '';
    };
  };
}
