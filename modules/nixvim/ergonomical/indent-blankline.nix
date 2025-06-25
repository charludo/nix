{ config, ... }:
{
  plugins.indent-blankline = {
    enable = true;
    settings = {
      indent = {
        char = "│";
        highlight = "IblChar";
      };
      scope = {
        char = "│";
        highlight = "IblScopeChar";
      };
      exclude = {
        buftypes = [
          "terminal"
          "quickfix"
        ];
        filetypes = [
          "checkhealth"
          "help"
          "lspinfo"
          "TelescopePrompt"
          "TelescopeResults"
        ];
      };
    };
  };

  highlight = {
    IblChar = {
      fg = config.palette.line;
    };
    IblScopeChar = {
      fg = config.palette.grey;
    };
    "@ibl.scope.underline.1" = {
      bg = config.palette.black2;
      underline = false;
      cterm = null;
    };
  };
  highlightOverride = {
    "@ibl.scope.underline.1" = {
      bg = config.palette.black2;
      underline = false;
      cterm = null;
    };
  };
}
