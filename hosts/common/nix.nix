{
  inputs,
  lib,
  private-settings,
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

      http-connections = 128;
      max-substitution-jobs = 128;

      extra-substituters = [ "https://cache.${private-settings.domains.blog}" ];
      extra-trusted-public-keys = [
        "cache.${private-settings.domains.blog}-1:uh2KzANysUoaMiEesTO2IkE2h/ycuJKE3Jx8yz4XYJI="
      ];
    };

    gc = {
      automatic = lib.mkDefault true;
      dates = lib.mkDefault "weekly";
      options = lib.mkDefault "--delete-older-than 7d";
    };

    nixPath = [ "nixpkgs=${inputs.nixpkgs.outPath}" ];
  };
}
