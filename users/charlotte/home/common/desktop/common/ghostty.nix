{ config, ... }:
{
  programs.ghostty = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      theme = "custom";
    };
    themes.custom = {
      background = "1e1e2e";
      cursor-color = "f5e0dc";
      foreground = "cdd6f4";
      palette = [
        "0=#${config.colorScheme.palette.base00}"
        "1=#${config.colorScheme.palette.base01}"
        "2=#${config.colorScheme.palette.base02}"
        "3=#${config.colorScheme.palette.base03}"
        "4=#${config.colorScheme.palette.base04}"
        "5=#${config.colorScheme.palette.base05}"
        "6=#${config.colorScheme.palette.base06}"
        "7=#${config.colorScheme.palette.base07}"
        "8=#${config.colorScheme.palette.base08}"
        "9=#${config.colorScheme.palette.base09}"
        "10=#${config.colorScheme.palette.base0A}"
        "11=#${config.colorScheme.palette.base0B}"
        "12=#${config.colorScheme.palette.base0C}"
        "13=#${config.colorScheme.palette.base0D}"
        "14=#${config.colorScheme.palette.base0E}"
        "15=#${config.colorScheme.palette.base0F}"
      ];
      selection-background = "${config.colorScheme.palette.base03}";
      selection-foreground = "${config.colorScheme.palette.base08}";
    };
  };
}
