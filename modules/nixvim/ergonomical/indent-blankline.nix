{ config, ... }:
{
  programs.nixvim.plugins.indent-blankline = {
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

  programs.nixvim.highlight = {
    IblChar = {
      fg = config.nixvim.palette.line;
    };
    IblScopeChar = {
      fg = config.nixvim.palette.grey;
    };
    "@ibl.scope.underline.1" = {
      bg = config.nixvim.palette.black2;
      underline = false;
      cterm = null;
    };
  };
  programs.nixvim.highlightOverride = {
    "@ibl.scope.underline.1" = {
      bg = config.nixvim.palette.black2;
      underline = false;
      cterm = null;
    };
  };
}
