{
  projectRootFile = "flake.nix";

  programs = {
    nixfmt.enable = true;
    deadnix.enable = true;
    statix = {
      enable = true;
      disabled-lints = [ "repeated_keys" ];
    };

    ruff-check.enable = true;
    ruff-format.enable = true;
  };
}
