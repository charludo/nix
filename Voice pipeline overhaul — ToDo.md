# Voice pipeline overhaul — ToDo

Oct 22, 2026 · @Charlotte

## Status (Oct 25, 2026)

- **Phase 1:** done. The array runs the 1-channel firmware v3.0.0 (flashed with `respeaker-dfu`). DSP on chip defaults; the earlier tuning is kept in `home-assistant/satellite/dsp-tuning.nix`. Corpus (1.5) not recorded yet.
- **Phase 2:** open. Whisper now gets `language = "de"`; openWakeWord removed from SRV-VOICE.
- **Phase 3:** done. LVA 1.1.15 runs as a system service (`services.linux-voice-assistant`), wake word `okay_computer`/HA-chosen; LED ring via upstream's LVA controller (`hardware.respeaker-mic-array.leds`).
- **Decided outside Nix:** wake word, pipeline, sensitivity, finished-speaking detection and area live on the device page in HA. The reconciler only pins the satellite's entity id to `assist_satellite.satellite_wohnzimmer` (tts_relay's route).
- **Satellite Wi-Fi:** Nix-written profile pinned to 2.4 GHz, power saving and PMF off (WPA3/SAE fails on brcmfmac with NetworkManager 1.58).
- **Open issues:** runs that HA ends right after the wake word (needs HA debug logs); two hard resets of the Pi.

## Overview

Fix the mic first, then pick the fastest speech-to-text engine with real recordings, then swap the satellite to Linux-Voice-Assistant with microWakeWord. Each phase ends with a measurable "done when", so you can stop after any of them with a working setup.

| Host | Role after the overhaul | Ports to open |
| --- | --- | --- |
| Pi 4 (satellite) | Mic array, wake word (microWakeWord), speaker | 6053/tcp from the HA VM (ESPHome API), 5353/udp for mDNS discovery |
| Voice VM | Speech-to-text servers (Wyoming) | 10300–10303/tcp from the HA VM (one per engine under test) |
| HA VM | Assist pipeline: end-of-speech detection, intents, responses | unchanged |

HA opens both connections: to the Pi's ESPHome API and to the Voice VM's Wyoming servers. The Pi and the Voice VM never talk to each other.

&#91;embedded content: target setup · 3 hosts, 2 connections\]

One part is not declarable in Nix: Wyoming and ESPHome integrations and Assist pipelines are UI config stored in HA's `.storage`. Note the choices you make there in your repo next to the Nix code.

## Phase 1 — Mic array firmware and clean audio (Pi)

Goal: the satellite delivers exactly one channel, the XMOS-processed one. The Mic Array v2.0 ships with [two firmware variants](https://wiki.seeedstudio.com/ReSpeaker_Mic_Array_v2.0): `1_channel_firmware.bin` (processed audio for speech recognition) and `6_channels_firmware.bin` (channel 0 processed, channels 1–4 raw mics, channel 5 playback reference). With the 6-channel firmware, any software that downmixes all channels mixes raw mic noise back into the clean signal. That alone can explain both your false wakes and your misses.

### 1.1 Check what is running now

- [ ] Stop the current satellite service so the device is free.
- [ ] `lsusb | grep 2886` → expect `2886:0018` (the array in normal mode).
- [ ] `arecord -l` → note the card name (often `ArrayUAC10`).
- [ ] `arecord -D hw:CARD=ArrayUAC10 --dump-hw-params -d 1 /dev/null` → read the `CHANNELS` line. `1` = processed firmware, done with 1.3. `6` = 6-channel firmware, flash in 1.3.
- [ ] Check what your current satellite config actually captures (`-c 1` through `plughw`/PipeWire on a 6-channel device = downmix).

### 1.2 Package the Seeed tools in Nix

The flasher (`dfu.py`), the DSP tuner (`tuning.py`) and both firmware files live in the [respeaker/usb\_4\_mic\_array](https://github.com/respeaker/usb_4_mic_array) repo. The scripts date from the Python 2.7 era, so expect a small fix or two under Python 3.

```nix
{ pkgs, lib, ... }:
let
  usb4mic = pkgs.fetchFromGitHub {
    owner = "respeaker";
    repo = "usb_4_mic_array";
    rev = "<pin a commit>";
    hash = lib.fakeHash; # replace after first build
  };
  py = pkgs.python3.withPackages (p: [ p.pyusb ]); # add whatever else the scripts import
  respeaker-dfu = pkgs.writeShellScriptBin "respeaker-dfu" ''
    exec ${py}/bin/python ${usb4mic}/dfu.py "$@"
  '';
  respeaker-tuning = pkgs.writeShellScriptBin "respeaker-tuning" ''
    exec ${py}/bin/python ${usb4mic}/tuning.py "$@"
  '';
in {
  environment.systemPackages = [ respeaker-dfu respeaker-tuning ];
  environment.etc."respeaker/1_channel_firmware.bin".source = "${usb4mic}/1_channel_firmware.bin";
  # lets tuning run without sudo
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTRS{idVendor}=="2886", ATTRS{idProduct}=="0018", MODE="0660", GROUP="audio"
  '';
}
```

### 1.3 Flash the 1-channel firmware (if 1.1 showed 6 channels)

- [ ] `sudo respeaker-dfu --download /etc/respeaker/1_channel_firmware.bin`
- [ ] Unplug and replug the array.
- [ ] Repeat the `--dump-hw-params` check → `CHANNELS: 1`.

Flashing is a one-time imperative step. Note the firmware variant in your repo so a replacement unit gets the same treatment.

### 1.4 Check and pin the DSP settings

- [ ] `respeaker-tuning -p` → lists all parameters with current values.
- [ ] Confirm automatic gain (`AGCONOFF`) and the noise suppression and echo cancellation switches are on. Take the exact parameter names from the `-p` output.
- [ ] Change one value, replug, read it back. If it reset, the settings are not persistent: apply them on every plug-in with a oneshot service.

```nix
systemd.services.respeaker-tune = {
  serviceConfig.Type = "oneshot";
  script = ''
    ${respeaker-tuning}/bin/respeaker-tuning AGCONOFF 1
    # … one line per parameter you settled on
  '';
};
services.udev.extraRules = ''
  ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="2886", ATTRS{idProduct}=="0018", TAG+="systemd", ENV{SYSTEMD_WANTS}+="respeaker-tune.service"
'';
```

### 1.5 Record a test corpus

These recordings drive Phase 2, so the engines are compared on your room and your voice.

- [ ] Record 20–30 real commands from your intents, at about 1 m and 4 m, once in a quiet room and once with TV or music on: `arecord -D hw:CARD=ArrayUAC10 -r 16000 -c 1 -f S16_LE -d 5 cmd01.wav`
- [ ] Next to each file, write `cmd01.txt` with the exact words spoken (the paired format `wyoming-bench` expects).
- [ ] Listen to a few. If the 4 m ones are muddy, move the array away from walls and the TV speaker before going on.

**Done when:** the array delivers 1 channel, the DSP settings survive a replug, and the corpus sounds clean.

## Phase 2 — Speech-to-text shoot-out (Voice VM)

Goal: pick the engine by measured accuracy and latency on your own corpus, not by benchmarks from someone else's hardware. Run every candidate side by side on its own port and keep the current one untouched as the baseline.

### 2.1 Separate end-of-speech delay from transcription time

- [ ] On the HA VM, set the current satellite's **Finished speaking detection** to aggressive.
- [ ] Settings → Voice assistants → your pipeline → Debug: note the per-stage times for a few commands. If speech-to-text itself is already well under a second, the delay you feel was end-of-speech detection and Phase 3 matters more than this one.

### 2.2 Run the candidates side by side

```nix
services.wyoming.faster-whisper.servers = {
  # current baseline, unchanged
  base = {
    enable = true;
    model = "base-int8";
    language = "en"; # your language
    device = "cpu";
    uri = "tcp://0.0.0.0:10300";
  };
  # same model, greedy decoding
  base-fast = {
    enable = true;
    model = "base-int8";
    beamSize = 1;
    language = "en";
    device = "cpu";
    uri = "tcp://0.0.0.0:10301";
  };
};
networking.firewall.allowedTCPPorts = [ 10300 10301 10302 10303 ];
```

If a server fails reading `/proc/cpuinfo`, add `systemd.services."wyoming-faster-whisper-<name>".serviceConfig.ProcSubset = lib.mkForce "all";` ([seen in this config](https://git.felschr.com/felschr/nixos-config/src/branch/main/services/home-assistant/wyoming.nix)).

- [ ] **Parakeet on 10302.** [franc2002/wyoming-parakeet](https://hub.docker.com/r/franc2002/wyoming-parakeet) runs parakeet.cpp with the nemotron-3.5-asr-streaming-0.6b model; the q8\_0 quantization is recommended and needs under 2 GB RAM. GPU acceleration is Vulkan-only, so on a CPU-only VM test it as-is. Check the [repo](https://github.com/albe873/wyoming-parakeet) for the internal port, model selection and language support before wiring it up:

```nix
virtualisation.oci-containers.containers.wyoming-parakeet = {
  image = "franc2002/wyoming-parakeet"; # pin a tag or digest
  ports = [ "10302:<internal port from the README>" ];
  volumes = [ "/var/lib/wyoming-parakeet:/data" ];
};
```

- [ ] **Whistle on 10303.** Use the `wyoming_whistle.py` bridge from earlier. `cactus-needle` is not in nixpkgs, so for the test run it in a small container (python 3.12 slim + `pip install cactus-needle wyoming` + the bridge). Package it properly with `buildPythonApplication` and `autoPatchelfHook` only if it wins. It covers 7 languages (en, de, fr, es, it, nl, pl).
- [ ] Optional: `small-int8` with `beamSize = 1` on 10304, if `base-fast` is fast but makes errors.

### 2.3 Benchmark with your corpus

[wyoming-bench](https://pypi.org/project/wyoming-bench/) talks to Wyoming servers directly and runs a corpus of paired recordings against several at once. It is on PyPI, so run it through `uv` from a nix shell:

```sh
nix shell nixpkgs#uv -c uvx wyoming-bench stt \
  voicevm:10300 voicevm:10301 voicevm:10302 voicevm:10303 \
  --corpus ./corpus --rounds 3
```

- [ ] Fill in the table. Look hardest at the 4 m and TV-on recordings and at your room and device names.

| Engine | Port | Errors (WER, %) | Latency p50 (ms) | Latency p95 (ms) | RAM (MB) |
| --- | --- | --- | --- | --- | --- |
| faster-whisper base-int8 (baseline) | 10300 |  |  |  |  |
| faster-whisper base-int8, beam 1 | 10301 |  |  |  |  |
| Parakeet (nemotron 3.5, q8\_0) | 10302 |  |  |  |  |
| Whistle | 10303 |  |  |  |  |

### 2.4 Wire the winner into HA

- [ ] HA VM: Settings → Devices & services → Add integration → Wyoming Protocol → host = Voice VM, port = the winner's.
- [ ] Settings → Voice assistants → your pipeline → Speech-to-text = the new entry.
- [ ] Remove the losing servers and their ports from the Voice VM config.

**Done when:** one engine is chosen with numbers behind it and the pipeline uses it.

## Phase 3 — Linux-Voice-Assistant with microWakeWord (Pi)

Goal: replace wyoming-satellite + openWakeWord with [Linux-Voice-Assistant](https://github.com/OHF-Voice/linux-voice-assistant) (LVA). It acts as an ESPHome voice device towards HA and runs microWakeWord or openWakeWord on the Pi itself; aarch64 is supported.

### 3.1 Pick a packaging route

- [ ] `nix search nixpkgs linux-voice-assistant` and `nix search nixpkgs pymicro-wakeword`. I found no nixpkgs package; Debian ships one, so the dependency list is settled.
- [ ] **Route A, to try it fast:** the prebuilt image from GitHub Container Registry (`ghcr.io/ohf-voice/linux-voice-assistant`) via `virtualisation.oci-containers`, host networking, the PipeWire/Pulse socket mounted in. Every parameter also exists as an environment variable ([install docs](https://github.com/OHF-Voice/linux-voice-assistant/blob/main/docs/install.md)).
- [ ] **Route B, to keep it:** `buildPythonApplication` from a pinned release tag. Runtime deps per the [Debian package](https://tracker.debian.org/media/packages/l/linux-voice-assistant/control-1.1.15-1): aioesphomeapi, getmac, python-mpv, netifaces2, numpy, pymicro-wakeword, pyopen-wakeword, soundcard, webrtc-noise-gain, websockets, zeroconf. The two wake-word packages bundle native inference code, so expect `autoPatchelfHook` if you package them yourself.

### 3.2 Audio stack on the Pi

LVA reads the mic through PulseAudio or PipeWire, not raw ALSA.

```nix
services.pipewire = {
  enable = true;
  pulse.enable = true;
  alsa.enable = true;
};
users.users.lva = {
  isNormalUser = true; # owns the PipeWire session
  extraGroups = [ "audio" ];
  linger = true;       # session runs without a login
};
```

Run LVA as a systemd user service of `lva`, or as a system service with `User = "lva"` and `XDG_RUNTIME_DIR=/run/user/<uid>`.

### 3.3 Configure LVA

- [ ] Run once with `--list-input-devices` and `--list-output-devices` and note the array's names.
- [ ] Service arguments:

```sh
linux-voice-assistant \
  --name living-room \
  --audio-input-device '<name from --list-input-devices>' \
  --audio-input-channels 1 \
  --audio-output-device '<name from --list-output-devices>' \
  --wake-model okay_nabu \
  --mic-noise-suppression 0 --mic-auto-gain 0 \
  --refractory-seconds 2 \
  --preferences-file /var/lib/lva/preferences.json \
  --download-dir /var/lib/lva/local \
  --port 6053 \
  --disable-peripheral-api
```

- `--audio-input-channels` defaults to 2; set 1 to match the Phase 1 firmware.
- `okay_nabu` is the default microWakeWord model; the `wakewords/` folder of the repo lists the others.
- WebRTC noise suppression and gain stay at 0 because the XMOS chip already does both. Raise them only if Phase 4 says so.
- Drop `--disable-peripheral-api` if you want buttons or LEDs through its WebSocket API (port 6055).

```nix
networking.firewall.allowedTCPPorts = [ 6053 ];
networking.firewall.allowedUDPPorts = [ 5353 ]; # mDNS, for auto-discovery
```

### 3.4 Cut over

- [ ] Disable the wyoming-satellite and openWakeWord services on the Pi.
- [ ] HA: delete the old Wyoming satellite device.
- [ ] HA: accept the discovered ESPHome device, or Add integration → ESPHome → host = Pi, port 6053.
- [ ] Device page: choose the pipeline from Phase 2, the wake word and **Finished speaking detection**.
- [ ] Smoke test: a command from 1 m and from 4 m, a timer, an announcement.

**Done when:** the Pi runs LVA as a Nix-managed service, HA sees it as an ESPHome device, and commands work from across the room.

## Phase 4 — Tune, measure, clean up

Goal: numbers for the two complaints you started with — false wakes and missed wakes.

- [ ] **False wakes:** leave TV or radio running for 24 h, then count pipeline runs nobody asked for (pipeline debug list or the satellite's history). Set yourself a target, e.g. at most one a day.
- [ ] **Missed wakes:** 20 tries at 1 m and 20 at 4 m, normal voice. Count the misses.
- [ ] Too many false wakes → try another microWakeWord model, raise `--refractory-seconds`, move the array away from the TV speaker.
- [ ] Too many misses → check the DSP gain from 1.4, then try `--mic-auto-gain` in small steps.
- [ ] Retime end-to-end in pipeline debug and compare against 2.1.
- [ ] Clean up: remove the old openWakeWord server wherever it ran, the losing STT servers, and their firewall ports.

**Later, if you want more:**

- Speech-to-Phrase v1.4.3 with `--custom-sentences-dir` pointed at your Nix-generated intents, plus a fallback proxy to Whisper for free-form slots.
- A custom wake word trained on recordings from this room.

## Sources

- [Seeed wiki: ReSpeaker Mic Array v2.0](https://wiki.seeedstudio.com/ReSpeaker_Mic_Array_v2.0)
- [Linux-Voice-Assistant README](https://github.com/OHF-Voice/linux-voice-assistant)
- [Debian control file for linux-voice-assistant 1.1.15](https://tracker.debian.org/media/packages/l/linux-voice-assistant/control-1.1.15-1)
- [NixOS options: services.wyoming.faster-whisper.servers](https://mynixos.com/options/services.wyoming.faster-whisper.servers.%3Cname%3E)
- [franc2002/wyoming-parakeet](https://hub.docker.com/r/franc2002/wyoming-parakeet)
- [wyoming-bench](https://pypi.org/project/wyoming-bench/)
- [Cactus Whistle model card](https://huggingface.co/Cactus-Compute/whistle)
