{
  nixpkgs.config.permittedInsecurePackages = [
    "libsoup-2.74.3" # used by Darktable

    "jitsi-meet-1.0.8043" # used by Jitsi
  ];
}
