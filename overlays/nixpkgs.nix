{ inputs }:
_: prev: {
  # NZBGet scripts require python
  nzbget = prev.nzbget.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ prev.python313 ];
  });

  # Used by GPU-VMs (esp. Jellyfin)
  vaapiIntel = prev.vaapiIntel.override { enableHybridCodec = true; };

  jellyfin-ffmpeg = prev.jellyfin-ffmpeg.override {
    # Exact version of ffmpeg_* depends on what jellyfin-ffmpeg package is using.
    # In 24.11 it's ffmpeg_7-full.
    # See jellyfin-ffmpeg package source for details
    ffmpeg_7-full = prev.ffmpeg_7-full.override {
      withMfx = false;
      withVpl = true;
      withUnfree = true;
    };
  };

  # Jellyfin already supports Qt6, but there hasn't been a release in a while
  jellyfin-media-player =
    inputs.nixpkgs-jmp-qt6.legacyPackages.${prev.stdenv.hostPlatform.system}.jellyfin-media-player.overrideAttrs
      (_: {
        version = "1.13.0-pre";
        src = prev.fetchFromGitHub {
          owner = "jellyfin";
          repo = "jellyfin-media-player";
          rev = "3ef86082bf2021f8bcd70e08ad19073b8d110685";
          sha256 = "sha256-M6CHuI9kmm+LJZ3LHvTVr4Luv/JYPDAtcLm67XO2ebw=";
        };
      });
}
