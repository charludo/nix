{ pkgs, inputs, ... }:
{
  home.packages = with pkgs; [
    musescore
    inputs.muse-sounds-manager.packages.x86_64-linux.muse-sounds-manager
  ];

  # Necessary until the MuseSampler lib issue is fixed, see:
  # https://github.com/musescore/MuseScore/issues/15562
  # https://github.com/NixOS/nixpkgs/issues/318210
  xdg.desktopEntries."org.musescore.MuseScore" = {
    name = "MuseScore Studio 4.3";
    icon = "mscore";
    type = "Application";
    comment = "Create, play and print beautiful sheet music";
    terminal = false;
    startupNotify = true;
    exec = "${pkgs.musescore}/bin/mscore %U";
    categories = [ "AudioVideo" "Audio" "Graphics" "2DGraphics" "VectorGraphics" "RasterGraphics" "Publishing" "Midi" "Mixer" "Sequencer" "Music" "Qt" ];
    mimeType = [
      "application/x-musescore"
      "application/x-musescore+xml"
      "x-scheme-handler/musescore"
      "application/vnd.recordare.musicxml"
      "application/vnd.recordare.musicxml+xml"
      "audio/midi"
      "application/x-bww"
      "application/x-biab"
      "application/x-capella"
      "audio/x-gtp"
      "application/x-musedata"
      "application/x-overture"
      "audio/x-ptb"
      "application/x-sf2"
      "application/x-sf3"
    ];
  };
}
