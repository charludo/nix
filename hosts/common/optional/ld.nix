{ options, pkgs, ... }:
{
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    ruff
  ] ++ options.programs.nix-ld.libraries.default;
}
