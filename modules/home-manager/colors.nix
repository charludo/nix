{
  config,
  lib,
  ...
}:
let
  cfg = config.colors;
in
{
  options.colors = {
    base = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      description = "the base16 color scheme everything is derived from";
    };

    palette = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      default = lib.colors.extendPalette cfg.base;
      defaultText = lib.literalExpression "lib.colors.extendPalette cfg.base";
      description = "the base16 colors plus the derived named colors";
    };

    paletteStripped = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      default = builtins.mapAttrs (_: lib.removePrefix "#") cfg.palette;
      defaultText = lib.literalExpression ''builtins.mapAttrs (_: lib.removePrefix "#") cfg.palette'';
      description = "same as `colors.palette`, but without the leading `#`";
    };
  };
}
