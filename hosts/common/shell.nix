{ pkgs, ... }:
{
  fish.enable = true;
  snow.enable = true;
  environment.shells = with pkgs; [
    fish
    bash
  ];
}
