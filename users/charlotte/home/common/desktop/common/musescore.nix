{ pkgs, ... }:
{
  home.packages = with pkgs; [
    musescore
    muse-sounds-manager
  ];
}
