{ config, lib, ... }:
let
  colors = import ../colors.nix { inherit config lib; };
in
{
  programs.nixvim.plugins.lualine = {
    enable = true;
    globalstatus = true;
    componentSeparators.left = "";
    componentSeparators.right = "";
    sectionSeparators.left = "";
    sectionSeparators.right = "";

    sections = {
      lualine_a = [ "mode" ];
      lualine_b = [ "filename" ];
      lualine_c = [ "branch" ];
      lualine_x = [ "diagnostics" ];
      lualine_y = [ "searchcount" "location" ];
      lualine_z = [ "progress" ];
    };

    theme = lib.mkForce {
      normal.a = { fg = colors.base01; bg = colors.base0B; };
      normal.b = { fg = colors.base05; bg = colors.base02; };
      normal.c = { fg = colors.base04; bg = colors.base01; };

      insert.a = { fg = colors.base01; bg = colors.base0A; };
      insert.b = { fg = colors.base05; bg = colors.base02; };
      insert.c = { fg = colors.base04; bg = colors.base01; };

      visual.a = { fg = colors.base01; bg = colors.base09; };
      visual.b = { fg = colors.base05; bg = colors.base02; };
      visual.c = { fg = colors.base04; bg = colors.base01; };

      terminal.a = { fg = colors.base01; bg = colors.base08; };
      terminal.b = { fg = colors.base05; bg = colors.base02; };
      terminal.c = { fg = colors.base04; bg = colors.base01; };

      command.a = { fg = colors.base01; bg = colors.base0D; };
      command.b = { fg = colors.base05; bg = colors.base02; };
      command.c = { fg = colors.base04; bg = colors.base01; };

      inactive.a = { fg = colors.base03; bg = colors.base01; };
      inactive.b = { fg = colors.base03; bg = colors.base01; };
      inactive.c = { fg = colors.base03; bg = colors.base01; };
    };
  };

  programs.nixvim.opts = {
    # would be nice... 
    # cmdheight = 0;
    laststatus = 3;
    shortmess = {
      C = true;
      F = true;
      A = true;
      W = true;
      I = true;
      S = true;
    };
  };
}
