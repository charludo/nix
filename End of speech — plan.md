# End of speech — plan

**Status (Nov 11): done, a success.** Silero + Smart Turn runs in the parakeet STT server on SRV-VOICE (`--endpointing`, deployed Nov 11, 13:02).
- **First live test:** 12 of 12 commands ended by Smart Turn; transcripts complete; no STT errors in HA.
- **Mid-sentence pause handled:** in "Setze Joghurt auf meiner Einkaufsliste", Smart Turn rated the pause 0.02 and kept listening, then 0.98 at the real end.
- **Text arrives ~0.1 s after the decision.**
- **Your verdict:** "MUCH better".

Goal: the satellite should notice sooner that you've stopped speaking. Today, from your last word until HA has the text takes 0.9 s (median; slowest 10 %: 1.3 s). About 0.8 s of that is waiting for the end-of-speech decision; STT (0.14 s), intents and TTS are fast.

## How it works today

- LVA streams the microphone to HA as it arrives. HA's `assist_pipeline` on the HA VM decides when you're done:
  - `pymicro_vad` gives a speech probability every 10 ms;
  - "Finished speaking detection: aggressive" means the probability must stay ≤ 0.5 for 0.25 s;
  - the command must be at least 1 s long.
- HA also forwards the audio to the STT server (parakeet on SRV-VOICE) while you speak. But the server only collects it, and transcribes once the audio ends (`handler.py`: `AudioChunk` → wav, `AudioStop` → `recognize`).
- A satellite can end the audio itself (`VoiceAssistantAudio(end=True)`). HA's esphome satellite treats that as a stop, not an abort, and runs STT right away.

## Benchmark (Nov 11)

**Data:** 157 recorded commands (Nov 1–11, from the activation log; replies such as "nicht verstanden" excluded).

**Your real last word:** the earliest cut of the audio at which parakeet still returns the full transcript (binary search).

**Setup:**
- Each detector runs causally: at each step it only sees the audio up to "now".
- All go through HA's own end-of-speech logic (`VoiceCommandSegmenter`, replicated).
- The replay of today's setting lands within 0.14 s (median) of the real `stt_text` event.

**What's measured:**
- **wait:** seconds from your last word until the detector ends the recording;
- **lost words:** commands whose transcript, cut at that point, misses or garbles the last words compared to the full recording. STT at a cut is sensitive to a few ms, so even the slowest settings land at 13–20 of 157.

| Detector | Setting (silence / threshold) | Wait, median | Wait, slowest 10 % | Lost words | Never ended |
|---|---|---|---|---|---|
| **HA today** (`pymicro_vad`) | 0.25 s / 0.5 | 0.78 s | 1.14 s | 25 | 1 |
| HA, stricter | 0.1 s / 0.7 | 0.59 s | 0.95 s | 30 | 0 |
| **Silero** (pysilero-vad 3.4) | 0.3 s / 0.35 | 0.54 s | 0.81 s | 28 | 2 |
| Silero | 0.4 s / 0.35 | 0.63 s | 0.91 s | 27 | 3 |
| Silero | 0.2 s / 0.5 | 0.42 s | 0.69 s | 33 | 1 |
| Silero | 0.1 s / 0.5 | 0.35 s | 0.62 s | 30 | 1 |
| **TEN VAD** (official lib) | 0.3 s / 0.35 | 0.57 s | 1.20 s | 28 | 9 |
| TEN VAD | 0.2 s / 0.5 | 0.31 s | 0.65 s | 39 | 0 |
| **MarbleNet** (NeMo frame VAD v2, 3rd-party ONNX) | 0.3 s / 0.35 | 0.44 s | 0.69 s | 35 | 6 |
| MarbleNet | 0.1 s / 0.5 | 0.22 s | 0.57 s | 39 | 6 |

The full sweep is in the scratchpad (`eval2/bench.json`).

CPU per second of audio (x86, 1 thread): `pymicro_vad` 8.6 ms, Silero 6.0 ms, TEN 5.2 ms. MarbleNet takes 93 ms when run causally, because it is a convolutional network over a window and has to re-run the whole 2 s window every 20 ms. None of them need the NPU.

**Findings:**
- **Silero** is the clear winner among plain voice detectors: about 0.25 s faster than today for 2–3 more clipped commands out of 157, and the slowest cases improve the most (1.14 → 0.81 s).
- **TEN VAD** keeps hearing speech in room noise. The slowest cases get worse, and it often never ends.
- **MarbleNet** reacts fastest, but clips more, fails to end 6 times, and costs 15× the CPU when run live.
- **No detector gets the wait much below ~0.4 s without clipping more often.** The commands that lose words at short silences are mostly natural pauses ("Erinnere mich in zwei Stunden an …") or trailing consonants ("Strahler aus" → "strahlungs"). A pure sound detector can't tell those apart from the end. That needs the meaning: steps 3 and 4.
- **"Very aggressive plus 0.3 s of padding" is the same as a 0.3 s longer silence.** Only the audio recorded up to the end point exists, so padding means waiting.

### Smart Turn (Nov 11)

Pipecat Smart Turn v3.2 (CPU ONNX, 8.7 MB, Whisper features; Pipecat's own benchmark puts German at 96 % accuracy), used the way Pipecat uses it:
- Silero (threshold 0.35) watches for a short silence;
- at that moment Smart Turn judges the command so far (last ≤ 8 s): finished or not;
- finished → end; not finished → wait until speech resumes, and ask again at the next short silence;
- after a longer silence ("fallback"), end anyway.

| Short silence / fallback / Smart Turn threshold | Wait, median | Wait, slowest 10 % | Lost words | Never ended |
|---|---|---|---|---|
| HA today, for comparison | 0.78 s | 1.14 s | 25 | 1 |
| Silero alone, 0.1 s, for comparison | 0.35 s | 0.62 s | 30 | 1 |
| **0.1 s / 0.6 s / 0.7** | **0.39 s** | **0.68 s** | **26** | 5 |
| 0.1 s / 0.6 s / 0.5 | 0.39 s | 0.66 s | 27 | 4 |
| 0.1 s / 1.0 s / 0.7 | 0.40 s | 0.74 s | 26 | 7 |
| 0.2 s / 0.6 s / 0.7 | 0.48 s | 0.78 s | 27 | 4 |
| 0.1 s / 0.6 s / 0.9 | 0.44 s | 0.79 s | 25 | 6 |

- **Silero + Smart Turn halves the wait** (0.78 → ~0.4 s, slowest 10 %: 1.14 → 0.68 s), at today's rate of lost words. Silero alone at that speed loses 30.
- **Not yet in the numbers:** Smart Turn's own compute time, 60 ms per call (x86, 1 thread, ~2 calls per command).
- **Never ended:** these are cases where Silero never hears 0.6 s of silence (TV, noise) within the recorded window. HA's own detector covers them, as today.
- **Too slow for the Pi** (estimated ~300 ms per call). Fine on SRV-VOICE or the HA VM.

### Very aggressive Silero + Smart Turn, and "re-run STT until stable" (Nov 11)

From here on, Smart Turn's 60 ms per call are added wherever it makes the decision. The fallback is always 0.6 s of silence.

| Approach | Wait, median | Wait, slowest 10 % | Lost words | Never ended |
|---|---|---|---|---|
| HA today | 0.78 s | 1.14 s | 25 | 1 |
| Silero 0.35, ask Smart Turn after 0.1 s, threshold 0.7 | 0.45 s | 0.73 s | 24 | 5 |
| Silero 0.5, ask after 0.064 s, threshold 0.7 | 0.38 s | 0.68 s | 27 | 2 |
| Silero 0.5, ask after 0.032 s, threshold 0.7 | 0.35 s | 0.65 s | 28 | 2 |
| Silero 0.7, ask after 0.032 s, threshold 0.5 (most aggressive) | 0.30 s | 0.61 s | 33 | 2 |
| STT every 0.15 s, end when two runs agree, no further condition | −0.29 s | 0.24 s | 79 | 2 |
| … every 0.25 s, no further condition | 0.25 s | 0.44 s | 45 | 4 |
| … every 0.15 s, plus Silero silence ≥ 0.064 s | 0.35 s | 0.65 s | 28 | 3 |
| … every 0.15 s, plus Silero silence, plus Smart Turn > 0.5 | 0.37 s | 0.71 s | 25 | 9 |
| … every 0.25 s, plus Silero silence | 0.43 s | 0.73 s | 25 | 6 |

- **There's a floor at ~0.3 s.** Silero needs ~0.2 s after the last word to report silence, and Smart Turn adds 60 ms. Re-asking Smart Turn during a pause (every 0.1 s) changes almost nothing.
- **Stable text alone is useless.** The text often stays the same between runs while you're still speaking (mid-word, short pauses), so it cuts in early.
- **With a Silero gate, it's no faster** than Silero + Smart Turn at the same rate of lost words. It costs 8–12 STT runs per command on the NPU, and the text arrives no earlier: a run on the audio up to t finishes at t + 0.14 s, the same as a single run after the end.
- **Noise:** differences of ±3 lost words out of 157 are within the metric's noise.

## Where it would run

HA's Wyoming STT client (`homeassistant/components/wyoming/stt.py`) already returns as soon as the STT server sends a `Transcript`, even while audio is still coming in, and cancels the upload. LVA stops streaming on `STT_END`.

So Silero and Smart Turn can live in our parakeet server on SRV-VOICE:
- it watches the incoming audio and transcribes as soon as it decides you're done;
- HA's `pymicro_vad` stays as the fallback, and whichever is faster wins;
- no patch to HA or LVA, and turning it off restores today's behaviour;
- HA's "Finished speaking detection" setting no longer applies; the settings live in the server's config.

## Plan

1. **Done (Nov 11): Silero + Smart Turn in the parakeet server** (`pkgs/by-name/wyoming-parakeet-npu/endpointing.patch`):
   - **Pitfall, fixed in the second deploy:** after answering early, the server must not close the connection. HA is still sending audio. Closing with unread data resets the connection, and HA's Wyoming client then raises while closing and reports "speech-to-text failed", even though the transcript had arrived. The server now discards further audio until HA hangs up.
   - **Logs:** `journalctl -u wyoming-parakeet-npu | grep -E "End of speech|stopped by the client"`. "turn" means Smart Turn ended it, "silence" means the 0.6 s fallback, "stopped by the client" means HA's VAD was faster.

   The plan as written before the build:
   - end-of-speech logic as benchmarked: Silero at 0.35, a 0.1 s short silence, a 0.6 s fallback, Smart Turn at 0.7;
   - when it decides you're done, transcribe and send the `Transcript` early;
   - behind an option.
   - **Expected:** median wait ~0.45 s instead of 0.78 s (including Smart Turn's compute time).
   - **Check after deploy:** compare the time from `listening` to `stt_text` in the activation log, and the "nicht verstanden" rate, against the past days.
   - **Alternative:** Silero alone in HA (patch `assist_pipeline/audio_enhancer.py`), which saves only ~0.2 s.
2. **Speculative STT** (optional, small): as soon as a short silence is detected, start STT on what's there, while the normal silence continues.
   - Speech resumes: discard the result.
   - Silence confirmed: the text is already there.
   - Saves the 0.14 s of STT. Only the text is speculative; nothing is executed early.
3. **Shelved for now (Nov 11): decide by the text.** Using the same data:
   - **Interim text:** transcribe the growing recording every 0.25 s (parakeet on the NPU takes ~0.14 s per run).
   - **Check:** does the text already form a complete command (hassil against our sentences and HA's built-in intents)?
   - **If yes:** end after a very short silence (Silero, 0.1 s). **If not:** wait the normal silence.
   - **Measure** the wait and the lost words, as above.
   - **Expected:** about 0.3 s for known commands, with fewer clipped pauses than today.
4. **Done: end-of-turn model.** Smart Turn, see above.
4b. **Done, not pursued: re-run STT until the text stops changing.** See above: no faster than Silero + Smart Turn, and much more NPU time.
5. **Depending on 3/4, build it:**
   - parakeet server: interim results (Wyoming `transcript-start`/`transcript-chunk`, or a separate request for each interim transcription);
   - a patch to HA's pipeline that ends early on a complete command;
   - LVA stays unchanged.
6. **Not pursued:** TEN VAD (keeps hearing speech in room noise, worse on the slowest cases). MarbleNet only if steps 3/4 need a fast frame-level detector, and then exported ourselves from NVIDIA's `.nemo` rather than the third-party ONNX.

## Reproduce

The scripts are in the session scratchpad (`eval2/`: `trueend.py`, `probs.py`, `bench.py`), which is temporary. The data comes from `/var/lib/lva-activation-log`. If this is pursued, move the scripts into the repo, e.g. `home-assistant/satellite/eval/`.
