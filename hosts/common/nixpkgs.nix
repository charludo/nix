{ outputs, pkgs, ... }:
{
  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays;
    config = {
      allowUnfree = true;
    };
  };

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
