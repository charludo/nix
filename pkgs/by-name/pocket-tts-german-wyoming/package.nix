{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "pocket-tts-german-wyoming";
  version = "0.2.0-unstable-2026-10-08";

  src = fetchFromGitHub {
    owner = "marco-taylor";
    repo = "pocket-tts-german-wyoming";
    rev = "f14ffe0652054a454d82c9ca76bd16bf830f20dd";
    hash = "sha256-YlSyKAC2EmCETZHaFef5YUWOu/9EEATrt8IqOPy6QzM=";
  };

  cargoLock.lockFile = "${src}/Cargo.lock";

  # Accept Wyoming streaming input (synthesize-start/-chunk/-stop) and
  # advertise it: Home Assistant only streams the audio of servers that do,
  # and otherwise waits for the whole reply. Audio was already streamed.
  patches = [ ./synthesize-streaming.patch ];

  # Upstream builds for Gracemont (.cargo/config.toml, target-cpu=gracemont);
  # the Core Ultra 5 225H in SRV-VOICE has all of its instructions.
  cargoBuildFlags = [
    "-p"
    "pocket-tts-wyoming"
  ];
  # Same scope as upstream's Dockerfile.
  cargoTestFlags = [
    "-p"
    "pocket-tts-runtime"
    "-p"
    "pocket-tts-wyoming"
    "--lib"
  ];

  meta = {
    description = "Wyoming text-to-speech server for Kyutai Pocket TTS (German), native Rust";
    homepage = "https://github.com/marco-taylor/pocket-tts-german-wyoming";
    # Code MIT; the model and voices (downloaded at runtime) are CC BY 4.0.
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "pocket-tts-wyoming";
  };
}
