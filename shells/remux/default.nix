{ pkgs, ... }:
pkgs.mkShell {
  nativeBuildInputs = [
    pkgs.mkvtoolnix-cli
    pkgs.ffmpeg
    (import ./remux.nix { inherit pkgs; })
    (import ./remux-all.nix { inherit pkgs; })
  ];
}
