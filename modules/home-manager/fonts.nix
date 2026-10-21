{
  lib,
  config,
  pkgs,
  ...
}:

let
  mkFontOption = kind: {
    family = lib.mkOption {
      type = lib.types.str;
      default = null;
      description = "Family name for ${kind} font profile";
      example = "Fira Code";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = null;
      description = "Package for ${kind} font profile";
      example = "pkgs.fira-code";
    };
    size = lib.mkOption {
      type = lib.types.int;
      default = 11;
      description = "Font size ${kind} font profile";
    };

  };

  cfg = config.fontProfiles;
in
{
  options.fontProfiles = {
    enable = lib.mkEnableOption "font profiles";
    monospace = mkFontOption "monospace";
    monospace_symbols = mkFontOption "monospace symbols";
    regular = mkFontOption "regular";
    serif = mkFontOption "serif";
    emoji = mkFontOption "emoji";
    japanese = mkFontOption "Japanese";
    japanese_serif = mkFontOption "Japanese serif";
  };

  config = lib.mkIf cfg.enable {
    fonts.fontconfig = {
      enable = true;

      defaultFonts = {
        sansSerif = [
          cfg.regular.family
          cfg.emoji.family
          cfg.japanese.family
        ];
        serif = [
          cfg.serif.family
          cfg.emoji.family
          cfg.japanese_serif.family
        ];
        monospace = [
          cfg.monospace.family
          cfg.monospace_symbols.family
          cfg.emoji.family
          cfg.japanese.family
        ];
        emoji = [ cfg.emoji.family ];
      };

      configFile.ignore-generic-family = {
        enable = true;
        priority = 50;
        settings.match = {
          "@target" = "pattern";
          edit = {
            "@name" = "genericfamily";
            "@mode" = "delete";
          };
        };
      };
    };

    home.packages = [
      cfg.monospace.package
      cfg.monospace_symbols.package
      cfg.regular.package
      cfg.serif.package
      cfg.emoji.package
      cfg.japanese.package
      cfg.japanese_serif.package

      pkgs.liberation_ttf
    ];

    gtk.font.name = cfg.regular.family;
    gtk.font.size = cfg.regular.size;
  };
}
