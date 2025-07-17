{ config, lib, ... }:
let
  cfg = config.desktop.ghostty;
  inherit (config.colorScheme) palette;
in
{
  options.desktop.ghostty.enable = lib.mkEnableOption "Ghostty terminal emulator";

  config = lib.mkIf cfg.enable {
    programs.ghostty = {
      enable = true;
      enableFishIntegration = true;
      clearDefaultKeybinds = true;
      settings = {
        theme = "custom";

        font-family = [
          config.fontProfiles.monospace.family
          config.fontProfiles.emoji.family
        ];
        font-size = config.fontProfiles.monospace.size;

        cursor-style = "block";

        window-padding-x = 10;
        window-padding-y = 10;

        confirm-close-surface = false;
      };
      themes.custom = {
        background = "${palette.base00}";
        cursor-color = "${palette.base07}";
        foreground = "${palette.base07}";
        palette = [
          "0=#${palette.base00}"
          "1=#${palette.base01}"
          "2=#${palette.base02}"
          "3=#${palette.base03}"
          "4=#${palette.base04}"
          "5=#${palette.base05}"
          "6=#${palette.base06}"
          "7=#${palette.base07}"
          "8=#${palette.base08}"
          "9=#${palette.base09}"
          "10=#${palette.base0A}"
          "11=#${palette.base0B}"
          "12=#${palette.base0C}"
          "13=#${palette.base0D}"
          "14=#${palette.base0E}"
          "15=#${palette.base0F}"
        ];
        selection-background = "${palette.base07}";
        selection-foreground = "${palette.base00}";
      };
    };
  };
}
