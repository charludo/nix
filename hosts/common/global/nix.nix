{ inputs, lib, pkgs, ... }:
{
  nix = {
    settings = {
      trusted-users = [ "root" "@wheel" ];
      auto-optimise-store = lib.mkDefault true;
      experimental-features = [ "nix-command" "flakes" "repl-flake" ];
      warn-dirty = true;
      system-features = [ "kvm" "big-parallel" ];
      # flake-registry = "";
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than +3";
    };

    # backwards compatibility / consistency
    # registry = lib.mapAttrs (_: value: { flake = value; }) inputs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs.outPath}" ];
  };
}
