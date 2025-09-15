{
  inputs,
  lib,
  ...
}:
{
  nix = {
    settings = {
      trusted-users = [
        "root"
        "@wheel"
      ];
      auto-optimise-store = lib.mkDefault true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = true;
      system-features = [
        "kvm"
        "big-parallel"
      ];
    };

    gc = {
      automatic = lib.mkDefault true;
      dates = lib.mkDefault "weekly";
      options = lib.mkDefault "--delete-older-than 3d";
    };

    nixPath = [ "nixpkgs=${inputs.nixpkgs.outPath}" ];
  };
}
