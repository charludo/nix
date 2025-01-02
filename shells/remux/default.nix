{ pkgs, lib, ... }:
pkgs.mkShell {
  nativeBuildInputs = [
    pkgs.mkvtoolnix-cli
    pkgs.ffmpeg
    (import ./remux.nix { inherit pkgs lib; })
  ];
}
