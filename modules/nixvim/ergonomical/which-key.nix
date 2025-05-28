{ config, ... }:
{
  programs.nixvim.plugins.which-key = {
    enable = true;
  };

  programs.nixvim.highlight = {
    WhichKey = {
      fg = config.nixvim.palette.blue;
    };
    WhichKeySeparator = {
      fg = config.nixvim.palette.light_grey;
    };
    WhichKeyDesc = {
      fg = config.nixvim.palette.red;
    };
    WhichKeyGroup = {
      fg = config.nixvim.palette.green;
    };
    WhichKeyValue = {
      fg = config.nixvim.palette.green;
    };
  };
}
