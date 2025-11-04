{ config, ... }:
let
  colors = config.palette;
in
{
  plugins.coverage = {
    enable = true;
    settings = {
      autoReload = true;
      keymaps = {
        coverage = "<leader>cc";
        toggle = "<leader>ct";
        summary = "<leader>cs";
      };

      highlights = {
        covered.fg = colors.dark_blue;
        partial.fg = colors.dark_purple;
        uncovered.fg = colors.orange;
      };
    };
  };
}
