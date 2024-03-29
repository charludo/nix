{ pkgs, ... }: {
  imports = [
    ./bat.nix
    ./bitwarden.nix
    ./fzf.nix
    ./gh.nix
    ./git.nix
    ./ssh.nix
    ./zsh.nix
  ];
  home.packages = with pkgs; [
    nil
    nixpkgs-fmt
  ];
}
