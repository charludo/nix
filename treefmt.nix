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

    shellcheck.enable = true;
    shfmt.enable = true;
    yamlfmt.enable = true;
    zizmor.enable = true;
    zizmor.includes = [
      ".forgejo/workflows/*.yml"
      ".forgejo/workflows/*.yaml"
      ".forgejo/actions/**/*.yml"
      ".forgejo/actions/**/*.yaml"
    ];
  };
}
