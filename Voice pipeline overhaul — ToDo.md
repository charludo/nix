# Voice pipeline overhaul — ToDo

Started Oct 22, 2026 · @Charlotte · last update Oct 26, 2026

## Where things stand

Done: satellite, speech-to-text and text-to-speech. Open: wake word reliability (section 4).

**Satellite (Pi 4, `home-assistant/satellite`)**

- ReSpeaker Mic Array v2.0 with the 1-channel firmware v3.0.0 (`respeaker-dfu`); DSP on chip defaults except a small noise/high-pass tuning (section 4).
- Linux-Voice-Assistant as a system service (`services.linux-voice-assistant`), microWakeWord on the Pi, HA connects via the ESPHome integration. LED ring follows LVA (`hardware.respeaker-mic-array.leds`).
- Wi-Fi: Nix-written profile pinned to 2.4 GHz, power saving and PMF off (NetworkManager 1.58 picks WPA3/SAE on the mixed-mode AP; brcmfmac can't do it).

**Voice VM (`vms/SRV-VOICE.nix`)**

- Speech-to-text: Parakeet Ultra on the Intel NPU (`wyoming-parakeet-npu`, port 10300).
- Text-to-speech: Kyutai Pocket TTS, German model (`pocket-tts`, port 10200).
- NPU passthrough (`modules/vms/npu.nix`): needs `intel_vpu force_snoop=1` in a VM, Intel's graph compiler (`pkgs/by-name/intel-npu-compiler`, missing from nixpkgs' driver) and the driver path on `LD_LIBRARY_PATH`. Run `sudo npu-check` after reboots; if the driver failed, `modprobe -r intel_vpu && modprobe intel_vpu` recovers it.

**Home Assistant**

- Managed in the UI, not in Nix: wake word, pipeline (incl. TTS voice), wake word sensitivity, finished-speaking detection and area on the satellite's device page.
- The reconciler only pins the satellite's entity id to `assist_satellite.satellite_wohnzimmer` (tts_relay routes by it).
- Replies go to the Sonos through tts_relay; the satellite plays into a silent dummy card. HA streams TTS through `/api/tts_proxy/<token>` while it is generated; the Sonos side plays instantly.

Benchmark corpus, scripts, results and TTS samples: `voice-pipeline-scratchpad-2026-10-26.tar.zst` (repo root, untracked).

## 1. Speech-to-text: Parakeet Ultra on the NPU

100 own recordings (near 42, far 31, couch 27), measured solo on SRV-VOICE (6 vCPU, unpinned, 4 threads). **Intent+slots** = the live chain (closest_intent, then HA's matcher) ends up with the same intent and slot values as for the corrected transcript (93 recordings in scope). **Wrong action** = a different intent or wrong slots get executed.

| Model | Device | Intent+slots | Couch | Wrong action | WER | Sentences exact | Mean / command | RAM |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Parakeet Ultra** (cibernox) — **live** | NPU | **96%** | **100%** | **1%** | 10.0% | **81%** | **0.11 s** | 5.1 GB⁴ |
| Parakeet Ultra (onnx-asr) | CPU | **96%** | **100%** | **1%** | 10.0% | **81%** | 0.98 s | 5.1 GB |
| Parakeet TDT 0.6B v3, fp32 (onnx-asr) | CPU | **96%** | **100%** | **1%** | 12.9% | 70% | 0.98 s | 4.9 GB |
| Parakeet TDT 0.6B v3 (cibernox) | NPU | 95% | 96% | **1%** | 13.8% | 70% | 0.12 s | 4.0 GB |
| whisper-large-v3-turbo-german (own int8 conversion) | NPU | 95% | 96% | 4% | 12.9% | 72% | 1.18 s | 4.5 GB |
| Qwen3-ASR 1.7B int8 (OpenVINO) | CPU | 94% | 88% | 3% | **9.7%** | 79% | 1.05 s | 4.5 GB |
| Canary 1B Flash | CPU | 92% | 88% | 3% | 12.2% | 77% | 1.51 s | 7.2 GB |
| Whisper large-v3-turbo int8 | CPU | 91% | 85% | 2% | 12.5% | 77% | ~25 s | – |
| Kroko zipformer `de` (streaming) | CPU | 91% | 81% | 5% | 14.7% | 70% | 0.40 s¹ | 0.3 GB |
| FastConformer `de` (NVIDIA, 115M) | CPU | 91% | 81% | 3% | 13.8% | 71% | **0.25 s** | 0.5 GB |
| Qwen3-ASR 0.6B int8 (OpenVINO) | CPU | 90% | 77% | 4% | 13.2% | 72% | 0.51 s | 2.0 GB |
| Whisper medium int8 | NPU | 89% | 85% | 5% | 22.9% | 64% | 0.97 s | 5.8 GB |
| Canary 1B v2 | CPU | 87% | 77% | 2% | 16.9% | 72% | 1.75 s | 8.2 GB |
| Qwen3-ASR 0.6B int4 | CPU | 85% | 73% | 3% | 19.7% | 57% | 1.30 s | 2.3 GB |
| Canary 180M Flash | CPU | 84% | 73% | 3% | 19.1% | 63% | 0.71 s | 2.6 GB |
| Whisper small int8 | CPU | 82% | 65% | 5% | 30.7% | 54% | 7.45 s | 1.5 GB |
| Nemotron 3.5 Streaming (eddy)² | NPU | 78% | 77% | 8% | 31.3% | 45% | 0.25 s | 4.7 GB |
| Nemotron 3.5 Streaming (eddy)² | CPU | 78% | 77% | 8% | 32.0% | 45% | 0.58 s | 11.7 GB |
| Parakeet Redux (ONNX)³ | CPU | 74% | 58% | 8% | 31.0% | 49% | 1.00 s | 1.2 GB |
| Vosk de-tuda-0.6-900k | CPU | 72% | 42% | 5% | 37.3% | 50% | 2.83 s | – |
| Parakeet TDT 0.6B v3, int8 (sherpa) | CPU | 63% | 46% | 5% | 36.1% | 46% | 0.65 s | 2.0 GB |
| Vosk de-0.21 | CPU | 62% | 31% | 5% | 44.5% | 43% | 1.21 s | – |
| Parakeet TDT 0.6B v3 (eddy)² | NPU | 59% | 23% | 6% | 48.6% | 43% | 0.22 s | 2.3 GB |
| Vosk small-de-0.15 | CPU | 59% | 19% | 13% | 44.8% | 41% | 0.66 s | 0.4 GB |
| Parakeet TDT 0.6B v3 (eddy)² | CPU | 58% | 27% | 8% | 47.3% | 42% | 1.51 s | 4.0 GB |
| Whisper base int8 | NPU | 58% | 35% | 9% | 65.5% | 20% | 0.17 s | 1.2 GB |
| Whisper base (previously live) | CPU | 54% | 27% | 15% | 63.6% | 24% | 3.49 s | 0.7 GB |
| Whistle (Cactus) | CPU | 45% | 23% | 17% | 69.3% | 24% | 0.21 s | 0.2 GB |

¹ Decodes while you speak; live latency after the end of speech is lower than this batch number.
² eddy's preprocessing tips Parakeet into English on hard recordings; the accuracy says nothing about the models. Timings are valid.
³ This ONNX export loses Redux's speed advantage, which comes from Moondream's own runtime (Photon).
⁴ Process memory; the first start also converts the model once (~11 GB peak) and the model files sit in the page cache (~5 GB, reclaimable).

Not possible / dropped: Qwen3-ASR on the NPU (GenAI hands the NPU dynamic shapes; [PR #4389](https://github.com/openvinotoolkit/openvino.genai/pull/4389) would fix it, closed unmerged), FluidInference's Whisper turbo NPU export (incompatible with GenAI), Whisper large-v3 on the NPU (compiles, then the first inference fails with `ZE_RESULT_ERROR_UNINITIALIZED`), whisper-tiny-german (crashes in PyTorch), distil-whisper-large-v3-german and the generic turbo on the NPU (not worth it).

Deployed: transcripts identical to the benchmark run. Encoder buckets 1.8/3.2/5/10 s, all compiled at startup (cached; ready ~12 s after start): 93 ms per command (was 105 ms with 5/10 s), accuracy unchanged. Commands in the corpus: 2.5 s median, 5.4 s max; longer audio is truncated to 10 s. A 20 s bucket needs ~11 GB to compile and gets OOM-killed even at 12 GB.

## 2. Text-to-speech: Pocket TTS (German)

Measured on SRV-VOICE (6 typical replies from "Erledigt." to a three-sentence weather report):

| Engine | First audio, mean | First audio, p95 | Total, mean | RTF |
| --- | --- | --- | --- | --- |
| Piper thorsten-high (previously live) | 1.39 s | 2.17 s | 2.25 s | 0.42 |
| Piper thorsten-medium | 0.29 s | 0.44 s | 0.46 s | 0.07 |
| Piper thorsten-low | 0.20 s | 0.34 s | 0.33 s | 0.05 |
| Kokoro Martin (CPU, onnxruntime) | 1.05 s | – | 1.63 s | 0.43 |
| Supertonic 3, 8 steps (CPU) | 2.98 s | 3.71 s | 4.51 s | 1.05 |
| Pocket TTS German, "juergen" (Python, in-process) | 0.19 s | 0.23 s | 1.87 s | 0.48 |
| Pocket server, upstream int8 default (over the network) | 0.79 s | 1.43 s | 4.03 s | 0.72 |
| **Pocket server, full precision — live** (over the network, 4 P-cores) | **0.07–0.08 s** | 0.09–0.12 s | 1.4–1.7 s | **0.33** |

Kokoro, Supertonic and Pocket (Python) were measured in-process on the VM, Piper and the Pocket server over Wyoming.

Candidates:

| Engine | German | NPU | Notes |
| --- | --- | --- | --- |
| Piper `thorsten-medium` | ✓ (same voice) | – | 5× faster first audio than `high`, but audibly worse than Pocket. Other German voices: `thorsten_emotional`, `kerstin`, `ramona`, `karlsson`, `pavoque`, `eva_k`, `mls` (236 speakers). |
| **Kyutai Pocket TTS** (Jun 2026) — **live** | ✓ dedicated German model, 27 preset German voices | – (PyTorch / native Rust) | 100M, streaming, voice cloning from 5–10 s. Weights CC BY 4.0. Wyoming servers: [marco-taylor/pocket-tts-german-wyoming](https://github.com/marco-taylor/pocket-tts-german-wyoming) (Rust, German normalisation; **used**), [ikidd/pocket-tts-wyoming](https://github.com/ikidd/pocket-tts-wyoming). Most natural of all, better than Piper `thorsten-high`. |
| Supertonic 3 (Supertone, Apr 2026) | ✓ (31 languages), 10 preset voices (M1–5, F1–5) | – (ONNX, CPU) | 99M flow-matching, 5–12 steps, 44.1 kHz. Weights OpenRAIL-M. Wyoming: [marco-taylor/supertonic3-tts-german-wyoming](https://github.com/marco-taylor/supertonic3-tts-german-wyoming), [domdomegg/wyoming-supertonic](https://github.com/domdomegg/wyoming-supertonic). Good quality and numbers, some pronunciation quirks; ~300 ms per step here, too slow. |
| NeuTTS Nano German (Neuphonic) | ✓ dedicated German model | – (llama.cpp GGUF) | 120M, real time on laptop CPUs, voice cloning from ~3 s; no Wyoming server found. |
| Kokoro-82M, German fine-tunes | ✓ Martin and Victoria ([kikiri-tts](https://huggingface.co/kikiri-tts), ONNX by [huggingFresse](https://huggingface.co/huggingFresse/Kokoro-82M-ONNX-German-Martin) with a Wyoming bridge, and [soniqo](https://huggingface.co/soniqo/Kokoro-82M-German-Martin-ONNX)), Kerstin, [Thorsten](https://huggingface.co/Thorsten-Voice/Kokoro) (PyTorch only) | runs, but slower | StyleTTS2, 82M, Apache-2.0. soniqo's static graph (what the NPU needs) always renders 3 s or 5 s of audio: 1.33 s on CPU, 1.77 s on the NPU (5 min compile). |
| OmniVoice (k2-fsa) | ✓ (600+ languages, voice cloning) | – | Built into wyoming-piper as `--backend omnivoice`. Diffusion-style, made for GPUs. |
| Qwen3-TTS 0.6B/1.7B | ✓ | uncertain | Very natural, streaming, voice cloning; autoregressive LLM, so the NPU hits the same dynamic-shape wall as Qwen3-ASR. |
| Chatterbox / F5 / Sopro | partly | – | GPU-oriented; skip. |

Notes on the live setup (`pkgs/by-name/pocket-tts-german-wyoming`, `systemd.services.pocket-tts`):

- **Voices** (picked per pipeline in HA; all equally fast): shortlist **alba, anna, charles, eve, jean, mary, michael, paul**. Fallback for requests without a voice: `eve`.
- **Numbers:** the model garbles digits; the server's German normaliser (on by default, profile `safe`) spells them out, including ordinals and case ("Am 3. November um 7:30" → "Am dritten November um sieben Uhr dreißig").
- **Full precision** (`POCKET_TTS_QUANTIZE=false`): upstream's int8 default is tuned for the N100 and is ~7× slower to first audio here.
- **Streaming:** HA only streams Wyoming TTS audio from servers that advertise streaming input, otherwise it waits for the whole reply. Upstream doesn't, so `synthesize-streaming.patch` accepts `synthesize-start/-chunk/-stop` and advertises it. Could be offered upstream.
- **Speed:** `tts.speed` in Nix (0.8–1.2, default 1.0), time-stretched after synthesis at no measurable cost.

## 3. Voice VM sizing

Measured Oct 26 from hub over the network. RAM: 4.5 GB used in total (Parakeet 3.0 GB, Pocket 0.7 GB), no paging at 8 GB; set to 12 GB for headroom when buckets compile (first start or a model change). STT needs ~0.2 CPU-s per command (the NPU does the work); TTS is the only real CPU user.

| vCPUs | Affinity | STT / command (mean, p95) | TTS first audio (mean, p95) | TTS RTF |
| --- | --- | --- | --- | --- |
| 6 | unpinned | 108 ms, 130 ms | 113–122 ms, 149–178 ms | 0.35–0.37 |
| 8 | 0-7 (P + first E-cluster) | 114–170 ms, 145–238 ms | 103–119 ms, 139–160 ms | 0.37–0.39 |
| **4** | **0-3 (P-cores) — live** | **105 ms, 120 ms** | **73–83 ms, 92–121 ms** | **0.33** |

Proxmox affinity applies to the whole VM, so with E-cores in the set the vCPUs drift onto them. px-gpu: 0-3 P-cores, 4-7 and 8-11 E-core clusters, 12-13 LP-E cores. `vm.hardware.cores`/`affinity` only apply at image creation; on the existing VM: `qm set 2402 --cores 4 --affinity 0-3`. SRV-TORRENTER stays unpinned.

## 4. Wake word: more reliable

Wake word: microWakeWord `okay_nabu` (trained on German among others; `okay_computer` and `hey_jarvis` are English-only). The HA "sensitivity" is the detection threshold itself (model default 0.85; lower = more permissive). Two wake words can be active at once.

**Base test (Oct 26)**, all defaults (threshold 0.85, LVA gain and noise suppression off, chip DSP defaults): 20 attempts per situation, recorded raw on the satellite and scored offline with the same model (reproduces all 91 live detections). Recording, scripts and results: `ww/` in the scratchpad archive.

| Situation | Attempts found | at 0.85 | at 0.70 | at 0.60 | at 0.50 | Median score |
| --- | --- | --- | --- | --- | --- | --- |
| quiet, near | 20 | 20 | 20 | 20 | 20 | 0.97 |
| quiet, far | 20 | 13 | 13 | 16 | 18 | 0.92 |
| quiet, couch | 23 | 19 | 22 | 22 | 22 | 0.96 |
| music, near | 20 | 7 | 10 | 11 | 11 | 0.69 |
| music, far | 9¹ | 4 | 6 | 7 | 8 | 0.81 |
| music, couch | 22 | 5 | 5 | 8 | 9 | 0.33 |
| TV, near | 19 | 14 | 17 | 18 | 18 | 0.93 |
| TV, far | 20 | 15 | 18 | 19 | 19 | 0.91 |
| TV, couch | 21 | 4 | 7 | 9 | 10 | 0.33 |

¹ The other music/far attempts left no score at all.

- The voice arrives at −24 to −26 dBFS everywhere: the chip's AGC already levels it. LVA's auto gain made things slightly worse, its noise suppression changed nothing (±1 attempt) → both off.
- Threshold 0.5 rescues far and TV near/far; no peak ≥ 0.5 in 8 min of pauses and conversation. False wakes during TV dialogue can't be told apart in this recording.
- What remains is masking (music, and TV at the couch), which the threshold can't fix.

Chip DSP (read from the array; firmware defaults otherwise): now `MIN_NN_SR` 0.3 → 0.15 (deeper suppression of non-stationary noise on the ASR output), `HPFONOFF` 1 → 2 (125 Hz high-pass against music bass), `CNIONOFF` 1 → 0 (no comfort noise), in `home-assistant/satellite/default.nix` (`hardware.respeaker-mic-array.tuning`). `GAMMA_NN_SR` is locked at 1.1 in the 1-channel firmware. The old 6-channel tuning (`dsp-tuning.nix`) is discarded.

- [ ] Step 1b (running since Oct 26, 14:35): real-world use with threshold 0.5 and the chip tuning above; count misses and false wakes from LVA's log (`ww/step1b.sh` in the scratchpad archive).
- [ ] If masking stays bad: re-record music near/couch and TV couch (~10 attempts each) to compare chip variants (e.g. `MIN_NN_SR` 0.1), and try placement (array vs. Sonos, TV, couch).
- [ ] Optional: "computer" community models (JohnnyPrimus, cutoff 0.66; TaterTotterson, cutoff 0.97) against `okay_nabu` with the same recorded protocol.
- [ ] Later: a custom wake word trained on recordings from this room (with its TV/music as negatives).

## Sources

- [Linux-Voice-Assistant](https://github.com/OHF-Voice/linux-voice-assistant)
- [wyoming-bench](https://pypi.org/project/wyoming-bench/)
- [cibernox/wyoming-parakeet-on-intel-npu](https://github.com/cibernox/wyoming-parakeet-on-intel-npu)
- [Moondream: Parakeet Redux and Ultra](https://moondream.ai/blog/introducing-parakeet-redux-and-ultra)
- [Intel linux-npu-driver #46](https://github.com/intel/linux-npu-driver/issues/46) (NPU in a VM: `force_snoop=1`)
- [openvino.genai PR #4389](https://github.com/openvinotoolkit/openvino.genai/pull/4389) (Qwen3-ASR on the NPU)
- [Kyutai Pocket TTS](https://github.com/kyutai-labs/pocket-tts)
- [marco-taylor/pocket-tts-german-wyoming](https://github.com/marco-taylor/pocket-tts-german-wyoming)
- [OpenVINO GenAI speech generation (Kokoro)](https://openvinotoolkit.github.io/openvino.genai/docs/samples/cpp/speech_generation/)
- [OmniVoice](https://github.com/k2-fsa/OmniVoice)
