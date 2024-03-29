{ pkgs, ... }:
{
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
}
