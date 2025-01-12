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
        "0=#${config.colorscheme.palette.base00}"
        "1=#${config.colorscheme.palette.base01}"
        "2=#${config.colorscheme.palette.base02}"
        "3=#${config.colorscheme.palette.base03}"
        "4=#${config.colorscheme.palette.base04}"
        "5=#${config.colorscheme.palette.base05}"
        "6=#${config.colorscheme.palette.base06}"
        "7=#${config.colorscheme.palette.base07}"
        "8=#${config.colorscheme.palette.base08}"
        "9=#${config.colorscheme.palette.base09}"
        "10=#${config.colorscheme.palette.base0A}"
        "11=#${config.colorscheme.palette.base0B}"
        "12=#${config.colorscheme.palette.base0C}"
        "13=#${config.colorscheme.palette.base0D}"
        "14=#${config.colorscheme.palette.base0E}"
        "15=#${config.colorscheme.palette.base0F}"
      ];
      selection-background = "${config.colorscheme.palette.base03}";
      selection-foreground = "${config.colorscheme.palette.base08}";
    };
  };
}
