{ config, ... }:
{
  plugins.which-key = {
    enable = true;
  };

  highlight = {
    WhichKey = {
      fg = config.palette.blue;
    };
    WhichKeySeparator = {
      fg = config.palette.light_grey;
    };
    WhichKeyDesc = {
      fg = config.palette.red;
    };
    WhichKeyGroup = {
      fg = config.palette.green;
    };
    WhichKeyValue = {
      fg = config.palette.green;
    };
  };
}
