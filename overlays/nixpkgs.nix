_: prev: {
  # NZBGet scripts require python
  nzbget = prev.nzbget.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ prev.python313 ];
  });

  # MA's stock Jellyfin provider never reads Jellyfin's Genres field.
  music-assistant = prev.music-assistant.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./patches/music-assistant-jellyfin-genres.patch ];
    disabledTests = (old.disabledTests or [ ]) ++ [
      "test_parse_albums"
      "test_parse_tracks"
    ];
    pytestFlagsArray = (old.pytestFlagsArray or [ ]) ++ [ "--snapshot-warn-unused" ];
  });
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (_: pyprev: {
      aiojellyfin = pyprev.aiojellyfin.overrideAttrs (a: {
        patches = (a.patches or [ ]) ++ [ ./patches/aiojellyfin-genres-field.patch ];
      });
    })
  ];
}
