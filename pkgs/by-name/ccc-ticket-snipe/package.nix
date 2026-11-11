{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  pname = "ccc-ticket-snipe";
  version = "0.3.0";
  meta.mainProgram = "ccc-ticket-snipe";

  # fixupPhase patches the shebang against this
  buildInputs = [ pkgs.python3 ];

  dontUnpack = true;

  installPhase = ''
    install -Dm755 ${./snipe.py} $out/bin/ccc-ticket-snipe
  '';
}
