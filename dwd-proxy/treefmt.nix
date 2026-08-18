_: {
  projectRootFile = "flake.nix";
  programs = {
    deadnix.enable = true;
    gofumpt.enable = true;
    nixfmt.enable = true;
    shellcheck.enable = true;
    shfmt.enable = true;
    statix.enable = true;
  };
}
