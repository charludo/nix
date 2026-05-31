_: prev: {
  # NZBGet scripts require python
  nzbget = prev.nzbget.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ prev.python313 ];
  });

  # MA's stock Jellyfin provider never reads Jellyfin's Genres field,
  # so library genres only come from online enrichers (theaudiodb …)
  # whose guesses are usually wrong. Patch the parser to copy genres
  # through from Jellyfin instead.
  music-assistant = prev.music-assistant.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./music-assistant-jellyfin-genres.patch ];
    # Upstream snapshot fixtures don't expect the new `genres` field on
    # parsed albums/tracks; the parse itself is correct. The
    # `--snapshot-warn-unused` flag downgrades syrupy's "unused
    # snapshot" exit-1 to a warning, since deselecting the test leaves
    # its snapshot orphaned.
    disabledTests = (old.disabledTests or [ ]) ++ [
      "test_parse_albums"
      "test_parse_tracks"
    ];
    pytestFlagsArray = (old.pytestFlagsArray or [ ]) ++ [ "--snapshot-warn-unused" ];
  });

  # The MA patch alone isn't enough: aiojellyfin decodes responses via
  # a mashumaro `BasicDecoder` over a TypedDict that doesn't declare
  # `Genres`, so the field is stripped before MA's parser ever sees
  # it. Patch aiojellyfin's MediaItem TypedDict to keep the field.
  #
  # `pythonPackagesExtensions` is appended to every python package
  # set's overrides (including the one MA builds internally via
  # `python3.override { packageOverrides = ... }`), so this is the
  # only place an override survives MA's nested re-override.
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (pyfinal: pyprev: {
      aiojellyfin = pyprev.aiojellyfin.overrideAttrs (a: {
        patches = (a.patches or [ ]) ++ [ ./aiojellyfin-genres-field.patch ];
      });
    })
  ];
}
