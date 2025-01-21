# shamelessly copied from: https://github.com/redyf/Neve/blob/main/config/snippets/luasnip.nix
{ pkgs, ... }:
{
  programs.nixvim.plugins.luasnip = {
    enable = true;
    settings = {
      enable_autosnippets = true;
      store_selection_keys = "<Tab>";
    };
    fromVscode = [
      {
        lazyLoad = true;
        paths = "${pkgs.vimPlugins.friendly-snippets}";
      }
    ];
  };
}
