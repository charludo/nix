{
  ours,
  python3Packages,
  ...
}:
python3Packages.buildPythonApplication {
  pname = "respeaker-led-bridge";
  version = "0.2.0";
  pyproject = true;
  src = ./.;

  build-system = [ python3Packages.setuptools ];

  dependencies = with python3Packages; [
    pyusb
    websockets # for the LED controller below
  ];

  # The LED ring controller is upstream's example for this exact board,
  # shipped in the Linux-Voice-Assistant repo. It follows LVA's state over
  # its peripheral WebSocket API (wake word, listening, thinking, speaking,
  # timers, mute) and also offers the ring to Home Assistant as a light.
  # Taken from the same pinned source as the LVA package.
  postInstall = ''
    install -Dm755 \
      "${ours.linux-voice-assistant.src}/examples/ReSpeaker Mic Array v2.0 (USB)/respeaker_usb_mic_array.py" \
      $out/bin/respeaker-led-bridge
  '';

  doCheck = false;

  meta.mainProgram = "respeaker-led-bridge";
}
