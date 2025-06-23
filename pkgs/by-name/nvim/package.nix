{
  lib,
  nixvim,
}:
let
  colors = {
    base00 = "#1c2128";
    base01 = "#373e47";
    base02 = "#444c56";
    base03 = "#545d68";
    base04 = "#768390";
    base05 = "#909dab";
    base06 = "#adbac7";
    base07 = "#cdd9e5";
    base08 = "#f47067";
    base09 = "#e0823d";
    base0A = "#c69026";
    base0B = "#57ab5a";
    base0C = "#96d0ff";
    base0D = "#539bf5";
    base0E = "#e275ad";
    base0F = "#ae5622";
  };
  colorsNoPound = builtins.mapAttrs (_name: value: builtins.substring 1 6 value) colors;
in
nixvim.legacyPackages.x86_64-linux.makeNixvim {
  imports = [ ../../../modules/nixvim ];
  colors = colorsNoPound;
  palette = lib.colors.extendPalette colorsNoPound;
  languages = { };
}
