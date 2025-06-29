{ lib, config, ... }:

let
  cfg = config.cli.k9s;
  colors = lib.colors.extendPalette config.colorScheme.palette;
in
{
  options.cli.k9s.enable = lib.mkEnableOption "enable themed k9s";

  config = lib.mkIf cfg.enable {
    programs.k9s = {
      enable = true;
      settings.k9s.ui.skin = "nix";
      skins = {
        nix = {
          k9s = {
            body = {
              fgColor = "${colors.base07}";
              bgColor = "${colors.base00}";
              logoColor = "${colors.base09}";
            };
            info = {
              fgColor = "${colors.base0C}";
              sectionColor = "${colors.base0D}";
            };
            frame = {
              border = {
                fgColor = "${colors.base09}";
                focusColor = "${colors.base0E}";
              };
              menu = {
                fgColor = "${colors.base0A}";
                keyColor = "${colors.base0D}";
                numKeyColor = "${colors.base0E}";
              };
              crumbs = {
                fgColor = "${colors.base07}";
                bgColor = "${colors.base0D}";
                activeColor = "${colors.base0C}";
              };
              status = {
                newColor = "${colors.sun}";
                modifyColor = "${colors.yellow}";
                addColor = "${colors.base0C}";
                errorColor = "${colors.base08}";
                highlightcolor = "${colors.base0D}";
                killColor = "${colors.base04}";
                completedColor = "${colors.base02}";
              };
              title = {
                fgColor = "${colors.nord_blue}";
                bgColor = "${colors.base02}";
                highlightColor = "${colors.base0C}";
                counterColor = "${colors.base09}";
                filterColor = "${colors.base02}";
              };
            };
            views = {
              table = {
                fgColor = "${colors.base07}";
                bgColor = "${colors.base00}";
                cursorColor = "${colors.nord_blue}";
                header = {
                  fgColor = "${colors.base00}";
                  bgColor = "${colors.base0D}";
                };
              };
              yaml = {
                keyColor = "${colors.dark_blue}";
                colonColor = "${colors.nord_blue}";
                valueColor = "${colors.green}";
              };
              logs = {
                fgColor = "${colors.base07}";
                bgColor = "${colors.base00}";
              };
            };
          };
        };
      };
    };
  };
}
