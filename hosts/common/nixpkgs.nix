{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    jq
    jless
    gcc
    unzip
    ripgrep
    killall
    wget
    dig
    traceroute
    pciutils
    ncdu
  ];
}
