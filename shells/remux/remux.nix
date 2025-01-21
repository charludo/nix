{ pkgs, lib, ... }:
pkgs.stdenv.mkDerivation {
  name = "remux";

  propagatedBuildInputs = [
    (pkgs.python3.withPackages (
      pythonPackages: with pythonPackages; [
        puremagic
        shellescape
        shortuuid
      ]
    ))
  ];
  nativeBuildInputs = [ pkgs.makeWrapper ];

  dontUnpack = true;

  installPhase = ''
    install -Dm755 ${./remux.py} $out/bin/remux
    wrapProgram $out/bin/remux \
      --prefix PATH : ${
        lib.makeBinPath [
          pkgs.mkvtoolnix-cli
          pkgs.ffmpeg
        ]
      }
  '';
}
