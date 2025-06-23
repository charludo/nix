{ config, ... }:
let
  colors = config.colors;
  palette = config.palette;
in
{
  imports = [
    ./bufferline.nix
    ./colorizer.nix
    ./lualine.nix
    ./nvim-tree.nix
    ./telescope.nix
    ./term.nix
  ];

  colorschemes.base16 = {
    enable = true;
    colorscheme = builtins.mapAttrs (_name: value: "#" + value) colors;
  };

  keymaps = [
    {
      mode = [ "n" ];
      key = "<leader>n";
      action = "<cmd>set nu!<CR>";
      options = {
        desc = "Toggle Line number";
      };
    }
    {
      mode = [ "n" ];
      key = "<leader>rn";
      action = "<cmd>set rnu!<CR>";
      options = {
        desc = "Toggle Relative number";
      };
    }
  ];

  plugins.web-devicons.enable = true;

  highlight = {
    MatchWord = {
      bg = palette.grey;
      fg = palette.white;
    };
    Pmenu = {
      bg = palette.one_bg;
    };
    PmenuSbar = {
      bg = palette.one_bg;
    };
    PmenuSel = {
      bg = palette.pmenu_bg;
      fg = palette.black;
    };
    PmenuThumb = {
      bg = palette.grey;
    };
    MatchParen = {
      link = "MatchWord";
    };
    Comment = {
      fg = palette.grey_fg;
      italic = false;
    };
    CursorLineNr = {
      fg = palette.white;
    };
    LineNr = {
      fg = palette.grey;
    };
    FloatBorder = {
      fg = palette.blue;
    };
    NormalFloat = {
      bg = palette.darker_black;
    };
    NvimInternalError = {
      fg = palette.red;
    };
    WinSeparator = {
      fg = palette.line;
    };
    Normal = {
      fg = palette.base05;
      bg = palette.base00;
    };
    DevIconDefault = {
      fg = palette.red;
    };
    Bold = {
      bold = true;
    };
    Debug = {
      fg = palette.base08;
    };
    Directory = {
      fg = palette.base0D;
    };
    Error = {
      fg = palette.base00;
      bg = palette.base08;
    };
    ErrorMsg = {
      fg = palette.base08;
      bg = palette.base00;
    };
    Exception = {
      fg = palette.base08;
    };
    FoldColumn = {
      fg = palette.base0C;
      bg = palette.base01;
    };
    Folded = {
      fg = palette.light_grey;
      bg = palette.black2;
    };
    IncSearch = {
      fg = palette.base01;
      bg = palette.base0A;
    };
    Italic = {
      italic = true;
    };
    Macro = {
      fg = palette.base08;
    };
    ModeMsg = {
      fg = palette.base0B;
    };
    MoreMsg = {
      fg = palette.base0B;
    };
    Question = {
      fg = palette.base0D;
    };
    Search = {
      fg = palette.base01;
      bg = palette.base09;
    };
    Substitute = {
      fg = palette.base01;
      bg = palette.base0A;
      sp = "none";
    };
    SpecialKey = {
      fg = palette.base03;
    };
    TooLong = {
      fg = palette.base08;
    };
    UnderLined = {
      underline = true;
    };
    Visual = {
      bg = palette.base02;
    };
    VisualNOS = {
      fg = palette.base08;
    };
    WarningMsg = {
      fg = palette.base08;
    };
    WildMenu = {
      fg = palette.base08;
      bg = palette.base0A;
    };
    Title = {
      fg = palette.base0D;
      sp = "none";
    };
    Conceal = {
      bg = "NONE";
    };
    Cursor = {
      fg = palette.base00;
      bg = palette.base05;
    };
    NonText = {
      fg = palette.base03;
    };
    SignColumn = {
      fg = palette.base03;
      sp = "NONE";
    };
    ColorColumn = {
      bg = palette.black2;
    };
    CursorColumn = {
      bg = palette.base01;
      sp = "none";
    };
    CursorLine = {
      bg = palette.black2;
    };
    QuickFixLine = {
      bg = palette.base01;
      sp = "none";
    };
    SpellBad = {
      undercurl = true;
      sp = palette.base08;
    };
    SpellLocal = {
      undercurl = true;
      sp = palette.base0C;
    };
    SpellCap = {
      undercurl = true;
      sp = palette.base0D;
    };
    SpellRare = {
      undercurl = true;
      sp = palette.base0E;
    };
    healthSuccess = {
      bg = palette.green;
      fg = palette.black;
    };
    DevIconc = {
      fg = palette.blue;
    };
    DevIconcss = {
      fg = palette.blue;
    };
    DevIcondeb = {
      fg = palette.cyan;
    };
    DevIconDockerfile = {
      fg = palette.cyan;
    };
    DevIconhtml = {
      fg = palette.baby_pink;
    };
    DevIconjpeg = {
      fg = palette.dark_purple;
    };
    DevIconjpg = {
      fg = palette.dark_purple;
    };
    DevIconjs = {
      fg = palette.sun;
    };
    DevIconkt = {
      fg = palette.orange;
    };
    DevIconlock = {
      fg = palette.red;
    };
    DevIconlua = {
      fg = palette.blue;
    };
    DevIconmp3 = {
      fg = palette.white;
    };
    DevIconmp4 = {
      fg = palette.white;
    };
    DevIconout = {
      fg = palette.white;
    };
    DevIconpng = {
      fg = palette.dark_purple;
    };
    DevIconpy = {
      fg = palette.cyan;
    };
    DevIcontoml = {
      fg = palette.blue;
    };
    DevIconts = {
      fg = palette.teal;
    };
    DevIconttf = {
      fg = palette.white;
    };
    DevIconrb = {
      fg = palette.pink;
    };
    DevIconrpm = {
      fg = palette.orange;
    };
    DevIconvue = {
      fg = palette.vibrant_green;
    };
    DevIconwoff = {
      fg = palette.white;
    };
    DevIconwoff2 = {
      fg = palette.white;
    };
    DevIconxz = {
      fg = palette.sun;
    };
    DevIconzip = {
      fg = palette.sun;
    };
    DevIconZig = {
      fg = palette.orange;
    };
    DevIconMd = {
      fg = palette.blue;
    };
    DevIconTSX = {
      fg = palette.blue;
    };
    DevIconJSX = {
      fg = palette.blue;
    };
    DevIconSvelte = {
      fg = palette.red;
    };
    DevIconJava = {
      fg = palette.orange;
    };
    DevIconDart = {
      fg = palette.cyan;
    };
  };
}
