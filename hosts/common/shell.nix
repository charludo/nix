{ lib, pkgs, ... }:
{
  fish.enable = true;
  snow = {
    enable = true;
    cache = lib.mkDefault "gsv";
  };
  environment.shells = with pkgs; [
    fish
    bash
  ];
}
