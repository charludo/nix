{
  fetchFromGitHub,
  python3Packages,
  ...
}:
let
  src = fetchFromGitHub {
    owner = "respeaker";
    repo = "usb_4_mic_array";
    rev = "00585f08779a816107f1668684815660aab2fe43";
    hash = "sha256-RMdDhgOe2YtGW9WSKZOus6Mbi0l7tQSx6xNvRP5UjLU=";
  };
in
# Firmware flasher for the ReSpeaker Mic Array v2.0 (XVF-3000), plus the
# firmware images it flashes. Flashing is a one-time imperative step:
#   sudo respeaker-dfu --download <out>/share/respeaker/1_channel_firmware.bin
# then replug the array. Only the top-level images (v3.0.0) apply to this
# board; MicArrayV3_firmware/ upstream is for the Mic Array V3.0 hardware.
python3Packages.buildPythonApplication {
  pname = "respeaker-dfu";
  version = "3.0.0-unstable-2025-08-11";
  format = "other";
  inherit src;

  dependencies = with python3Packages; [
    click
    pyusb
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 dfu.py $out/bin/respeaker-dfu
    install -Dm644 -t $out/share/respeaker 1_channel_firmware.bin 6_channels_firmware.bin
    runHook postInstall
  '';
}
