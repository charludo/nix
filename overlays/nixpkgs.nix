_: prev: {
  # NZBGet scripts require python
  nzbget = prev.nzbget.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ prev.python313 ];
  });

  # Needed for hyprland's new lua config. but can be dropped once nixpkgs carries waybar > 0.15.0.
  waybar = prev.waybar.overrideAttrs (old: {
    version = "0.15.0-unstable-2026-08-14";
    src = prev.fetchFromGitHub {
      owner = "Alexays";
      repo = "Waybar";
      rev = "09e69e0f48214a1128d62417612bc47e8dc9e36a";
      hash = "sha256-grYWj1RHrkhM0NCIymTsZyObuQsCVf1kuzLaThwMxvc=";
    };
    mesonFlags = old.mesonFlags ++ [ (prev.lib.mesonEnable "wwan" false) ];
    postUnpack = ''
      pushd "$sourceRoot"
      cp -R --no-preserve=mode,ownership ${
        prev.fetchFromGitHub {
          owner = "LukashonakV";
          repo = "cava";
          tag = "1.0.0";
          hash = "sha256-0r5aAmTs+FcmS501tNYKxG9H+Pq6i32BDRBEjWW6M74=";
        }
      } subprojects/cava-1.0.0
      patchShebangs .
      popd
    '';
    doInstallCheck = false;
  });

  # The mobile app needs the "-app" builds of backend and web. Upstream publishes no git tags for them, only the feature/app branch.
  wanderer = prev.wanderer.overrideAttrs (old: {
    version = "0.21.2-app-unstable-2026-10-30";
    src = prev.fetchFromGitHub {
      owner = "open-wanderer";
      repo = "wanderer";
      rev = "f07d0f01616c3c444ea4b19a237a3c7499a918e8";
      hash = "sha256-jQoKaIZcXvnSCFxiAzY43CRks84ZJtVZWZyfvhoMjUI=";
    };
    doCheck = false; # very expensive tests, idc
    passthru = old.passthru // {
      web = old.passthru.web.overrideAttrs (webOld: {
        # npmDepsHash is a builder argument, so only replacing npmDeps itself changes the fetched dependencies
        npmDeps = prev.fetchNpmDeps {
          inherit (webOld) src sourceRoot postPatch;
          name = "${webOld.pname}-${webOld.version}-npm-deps";
          hash = "sha256-4fbtL6OPpcjnBNU4vkCaoA9SJiKVfM6LSsK60V17Me4=";
          fetcherVersion = 2;
        };
      });
    };
  });

  # cargoSetupHook forces system aws-lc, can be dropped once nixpkgs carries https://github.com/NixOS/nixpkgs/pull/584921
  zizmor = prev.zizmor.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ prev.aws-lc ];
    nativeBuildInputs = old.nativeBuildInputs ++ [ prev.pkg-config ];
  });
  lk-jwt-service = prev.lk-jwt-service.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ prev.aws-lc ];
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.pkg-config ];
  });

  # Can be dropped once nixpkgs carries https://github.com/NixOS/nixpkgs/pull/584713
  anki = prev.anki.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ prev.pkg-config ];
    buildInputs = old.buildInputs ++ [
      prev.sqlite
      prev.zstd
    ];
    env = old.env // {
      UV_FIND_LINKS = prev.symlinkJoin {
        name = "uv-wheels";
        paths = [
          old.env.UV_FIND_LINKS
          prev.python3.pkgs.tomlkit.dist
        ];
      };
    };
  });

  # Can be dropped once nixpkgs carries https://github.com/NixOS/nixpkgs/pull/585183
  lrcget = prev.lrcget.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ prev.sqlite ];
  });

  # cargoSetupHook forces system zstd and aws-lc, which need pkg-config. No upstream fix yet.
  protonup-rs = prev.protonup-rs.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.pkg-config ];
    buildInputs = (old.buildInputs or [ ]) ++ [
      prev.zstd
      prev.aws-lc
    ];
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
  home-assistant-custom-lovelace-modules = prev.home-assistant-custom-lovelace-modules // {
    custom-sidebar = prev.home-assistant-custom-lovelace-modules.custom-sidebar.overrideAttrs (old: {
      passthru = (old.passthru or { }) // {
        entrypoint = "custom-sidebar.js";
      };
    });

    # nixpkgs only rewrites the HACS asset path in radar-toolbar.ts; the marker
    # icons, colour bars and preview image are still looked up under
    # /local/community/. buildEnv puts every file of the package into
    # /local/nixos-lovelace-modules/, so rewrite the path everywhere.
    weather-radar-card = prev.home-assistant-custom-lovelace-modules.weather-radar-card.overrideAttrs (old: {
      postPatch = ''
        grep -rlF "/local/community/weather-radar-card/" src \
          | xargs sed -i "s|/local/community/weather-radar-card/|/local/nixos-lovelace-modules/|g"
      '';
    });
  };

  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (_: pyprev: {
      spacy = pyprev.spacy.overridePythonAttrs (old: {
        disabledTests = (old.disabledTests or [ ]) ++ [ "test_entity_ruler_multiprocessing" ];
      });
      aiojellyfin = pyprev.aiojellyfin.overrideAttrs (a: {
        patches = (a.patches or [ ]) ++ [ ./patches/aiojellyfin-genres-field.patch ];
      });
      pyopen-wakeword = pyprev.pyopen-wakeword.overridePythonAttrs (_: {
        doCheck = false;
      });
    })
  ];
}
