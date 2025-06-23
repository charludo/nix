{
  mkShell,
  ffmpeg,
  mkvtoolnix-cli,
  remux,
  ...
}:
mkShell {
  packages = [
    remux
    ffmpeg
    mkvtoolnix-cli
  ];
}
