final: prev: {
  # NZBGet scripts require python
  nzbget = prev.nzbget.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ prev.python313 ];
  });

  # Avoid having to build Electron 39 (EOL, see insecure.nix)
  bitwarden-desktop = prev.bitwarden-desktop.override {
    electron_39 = final.electron_39-bin;
  };
}
