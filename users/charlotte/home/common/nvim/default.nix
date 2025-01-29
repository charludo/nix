{ pkgs, ... }:
{
  imports = [
    ./ergonomical
    ./languages
    ./technical
    ./ui
  ];

  xdg.desktopEntries.code = {
    name = "Code";
    type = "Application";
    comment = "Open NeoVim inside terminal";
    terminal = false;
    exec = "alacritty -e nvim";
    categories = [
      "Development"
      "Utility"
    ];
    icon = "nvim";
    mimeType = [ "text/*" ];
  };

  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    opts = {
      shell = "${pkgs.fish}/bin/fish";
      termguicolors = true;
      title = true;
      ignorecase = true;
      smartcase = true;
      wildmode = "longest:full,full";
      wrap = false;
      list = true;
      listchars = "tab:▸ ,trail:·";
      fillchars = "eob: ";
      mouse = "a";
      splitright = true;
      splitbelow = true;
      scrolloff = 8;
      sidescrolloff = 8;
      clipboard = "unnamedplus";
      confirm = true;
      expandtab = true;
      shiftwidth = 4;
      tabstop = 4;
      smartindent = true;
      softtabstop = 2;

      # Fold settings
      foldmethod = "expr";
      foldexpr = "nvim_treesitter#foldexpr()";
      foldenable = false;
      foldtext = ''
        substitute(getline(v:foldstart),'\\t',repeat('\ ',&tabstop),'g').'...'.trim(getline(v:foldend)) . ' (' . (v:foldend - v:foldstart + 1) . ' lines)'
      '';
      foldnestmax = 3;
      foldminlines = 1;

      laststatus = 3;
      showmode = false;

      cursorline = true;
      cursorlineopt = "number";

      number = true;
      numberwidth = 2;
      ruler = false;

      signcolumn = "yes";
      timeoutlen = 400;
      undofile = true;

      updatetime = 250;

    };

    extraConfigLua = # lua
      ''
        -- go to previous/next line with h,l,left arrow and right arrow
        vim.opt.whichwrap:append "<>[]hl"
      '';

    globals = {
      mapleader = " ";
      equalalways = false;
      python3_host_prog = "${pkgs.python3}/bin/python3";
      loaded_python3_provider = null;
      loaded_node_provider = null;
      loaded_perl_provider = null;
      loaded_ruby_provider = null;
    };
  };
}
