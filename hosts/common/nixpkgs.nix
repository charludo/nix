{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    jq
    gcc
    unzip
    ripgrep
    killall
    wget
    dig
    traceroute
  ];
}
