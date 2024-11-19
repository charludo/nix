{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "remux-all";
  runtimeInputs = [ (import ./remux.nix { inherit pkgs; }) ];
  text = ''
    find "/media/NAS/Filme & Serien/Anime" -type f -name "*.mkv" | while read -r file; do
        remux "$file"
    done
    find "/media/NAS/Filme & Serien/Serien" -type f -name "*.mkv" | while read -r file; do
        remux "$file"
    done
    find "/media/NAS/Filme & Serien/Filme" -type f -name "*.mkv" | while read -r file; do
        remux "$file"
    done
  '';
}
