{
  mkShell,
  ffmpeg,
  mkvtoolnix-cli,
  ours,
  ...
}:
mkShell {
  packages = [
    ours.remux
    ffmpeg
    mkvtoolnix-cli
  ];
}
