# Wake word — Observations and plan

Satellite `satellite-wohnzimmer` (ReSpeaker Mic Array v2.0, 1-channel firmware, LVA 1.1.15). Background and the Oct 26 base test: `Voice pipeline overhaul — ToDo.md`, section 4.

## State (Nov 1)

- Active wake words (set in HA, stored in LVA's `preferences.json`): **Computer (TaterTotterson)**, **Alexa at 0.5**. Computer was at 0.97 for the period of the activation log below and was lowered to **0.8** on the afternoon of Nov 1, before score logging started. LVA's mic gain and noise suppression are off; mic volume is 100.
- The chip runs firmware defaults except for the Nix tuning: `MIN_NN_SR` 0.15, `HPFONOFF` 2 and `CNIONOFF` 0. Checked by reading all 40 parameters live and comparing them with the Oct 26 dump. No temporary changes remain.
- The deployed system was exactly the committed `hass` config (before the rebase onto main).

## Activation log, Oct 27 – Nov 1

603 activations, all with audio (231 MB).

| | Count |
|---|---|
| Computer (TaterTotterson) | 454 |
| Alexa | 144 |
| Computer (JohnnyPrimus, Oct 27 only) | 5 |
| No reply (often no speech at all, many at night) | 222 |
| "Entschuldigung, das habe ich nicht verstanden" | 116 |
| Real commands answered | about 265 at most |

Roughly half of all activations are false wakes (TV, conversation, night-time noise).

## Findings from re-scoring clips offline

The models were run on activation clips on x86, the same way LVA does.

- **Timing:** detection always sits at 4.0–4.1 s in the clip, so the 4 s lead-in lines up and wake word segments can be cut reliably.
- **Offline scores are unreliable:** the score shifts by up to 0.25 depending on the 10 ms alignment of the model's steps (e.g. 0.57 vs 0.83 on the same clip). Two Computer activations that LVA detected live (above 0.97) reach only 0.59 and 0.87 offline. Only live scores count.
- **Ignored Alexa:** in two Alexa clips from Oct 28, an earlier "Alexa" at 1.9 s scores 0.89 and 0.93 offline, well above the 0.5 threshold, yet LVA only woke on the second one. LVA was idle, and no refractory period was running. Live scores (below) will show whether this recurs.
- **Steps per model:** each model has a fixed step size, set when it's trained (its stride, in 10 ms slices): 30 ms for alexa, okay_nabu, okay_computer, hey_jarvis and stop; 20 ms for computer_tatertotterson and hey_morgan. Each score is the average of the last 5 steps (8 for hey_morgan). Running several copies offset by 10 ms and taking the highest score acts like a lower threshold (more false wakes); not planned.
- **Alexa vs Computer:** a clearly spoken "Alexa" scores about 0.99 at every alignment. Computer stays at 0.6–0.85 even on real attempts, so that model is a poor fit for these voices and this room.

## Test: news on the Sonos (Nov 1, 17:49–17:58)

Setup:
- News playing on the Sonos at the usual volume; the satellite muted, so it kept scoring but didn't respond.
- Each round: "Computer" and "Alexa" said 6 times each, alternating, from 1.5 m, 2–3 s apart. Speech at normal to very loud volume.
- 80 s of mic audio recorded per round (exactly what LVA gets), plus the chip's beam direction (`DOAANGLE`), speech detection and AGC gain several times a second.

Recordings: `/tmp/wwtest/<round>/` on the satellite (gone after a reboot); copied to the scratchpad of the Nov 1 session.

| Round | Chip | Live LVA scores (12 attempts) | Beam (speech frames) | AGC gain |
|---|---|---|---|---|
| A | current tuning | one Computer at 0.81 (just over 0.8), one faint 0.09 | ~270° (the Sonos) | ~3 |
| B | `MIN_NN_SR` 0.3 | one Alexa at 0.47 (threshold 0.5) | ~270° | ~3 |
| C | non-stationary suppression off | nothing at all | ~270° | ~3 |
| D | beam frozen at the speaker (~60°) | three Computer at 0.06–0.17 | 60° (frozen) | 13.3, frozen too |

- **Beam:** with the news on, the beam points at the Sonos all the time; with the news off, at the speaker (~60°). The chip treats the news as "the talker".
- **Beam frozen:** pointing it at the speaker helps hardly at all. The voice simply doesn't stand out from the news at the array: on the loudness curve the attempts can't be told from the news, and offline re-scoring (all alignments) finds nothing either. The freeze also froze the AGC at its quiet-room gain, so round D is louder overall.
- **Gain control:** the news sets the AGC (gain ~3, against ~9 with only the speaker talking), so the voice ends up at news level or below.
- **Conclusion:** no chip setting fixes this. The voice-to-news ratio at the array is too low, and the models were never trained for speech at that level under speech.

### Options

1. **Placement:** every halving of the distance to the speaker, or doubling of the distance to the Sonos, gains ~6 dB. Satellite next to the couch, as far from the Sonos as possible, ideally with the Sonos behind the array.
2. **A wake word trained for this:** microWakeWord with news/TV mixed in at realistic, low voice-to-noise ratios; the recordings from this test are a starting point. Only realistic if the voice is at least somewhat audible in the recordings (listen first).
3. **Echo cancellation against the Sonos:** HA knows what the Sonos plays, but the stream reaches the Sonos with variable latency and gets processed. A software echo canceller with that as reference is a research project, not a setting.
4. **Different hardware:** an array with a reference input for the playback, or a second satellite closer to the couch.
5. **Fallback trigger:** a button (or phone/watch) to start listening when the room is loud.

## Test: on-chip echo cancellation against the Sonos (Nov 1, 18:15–18:30)

Idea: everything the Sonos plays comes from HA/MA, so the same audio can be played into the ReSpeaker's USB output (nothing on its jack). The XVF-3000 uses that as the reference for its echo canceller.

Setup:
- `wdrAktuell.mp3` from HA's news cache (`/local/news/`, byte-identical on every download), played on `media_player.living_room` at volume 0.31; the satellite muted meanwhile.
- **Sonos position:** cross-correlating the mic recording with the file gives where the Sonos is at a known time (correlation ~0.45).
- **Reference:** `ref.py` plays the file into the ReSpeaker output from that position plus a *lead*.
- **Measurement:** chip AGC off (gain fixed at 3), so levels are comparable. Per lead: 8 s without reference, 14 s with. The metric is mic energy / reference energy per 0.5 s window, so pauses in the news don't count. On vs off gives the reduction.
- **Scripts:** `/tmp/aec/` and `/tmp/wwtest/` on the satellite (gone after a reboot); analysis in the Nov 1 session's scratchpad.

Results:
- **Reference leaks into the capture:** playing only the reference (Sonos silent) shows up ~20 dB above silence (−50 vs −70 dBFS), clearly correlated with the file. The old "loops straight back" note in `satellite/default.nix` isn't entirely wrong; it's quiet, probably electrical crosstalk on the board. That leak also measures the delay from the player to the capture: 175 ms.
- **The canceller works, in a narrow window:**

  | Lead (frame of runs 3 and 4) | 25 | 50 | 75 | 100 | 115 | 125 | 130 | 145 | 160 | 175 |
  |---|---|---|---|---|---|---|---|---|---|---|
  | News reduced (dB) | 0.5 | −0.7 | 4.0 | **16.0 / 17.8** | 11.0 | 7.7 | 11.6 | 6.2 | 2.9 | 2.8 |

  Below ~75 ms the reference arrives after the echo and nothing is cancelled. Above ~130 ms the effect drops off quickly; the chip's echo filter is probably short. The usable window is about ±25 ms wide.
- **Run-to-run jitter:** the absolute lead shifts by tens of ms between runs (first two runs: best 2.9 and 8.7 dB at 150–200 ms), because the start-up of the recorder and player isn't constant. Runs 3 and 4 agree.

What this means:
- **Up to ~18 dB less news:** the voice goes from ~10 dB under the news to clearly above it. That's the first lever that's actually big enough.
- **Alignment has to be held within ~±20 ms, continuously.** Clocks drift (tens of ppm, i.e. up to seconds per day), and the Sonos may rebuffer. The alignment has to be measured from the signals themselves (cross-correlation of mic and reference, as in this test) and corrected on the fly, not computed once.

Wake word rounds with the reference on (R) vs off (N), 18:42–18:47. Same spot and news file, chip in normal operation (AGC on). 24 attempts per round (12 × Computer, 12 × Alexa, alternating); the news speaker changed halfway.

| Round | Live LVA scores | Offline (best of 3 alignments) | News share of the mic signal (correlation) |
|---|---|---|---|
| R, reference at lead 100 ms | Alexa 0.76 (over 0.5); 0.07–0.29 otherwise | Alexa 0.90 and 0.58 over 0.5, four more at 0.06–0.23; no Computer | 0.49 → 0.30 (sweep at its best: 0.54 → 0.26) |
| N, no reference | nothing | nothing | 0.43 |

- The canceller worked in round R about as well as at the best point of the sweep, and it does make a difference: 2 of 12 Alexas against 0. That's far from enough, and Computer doesn't respond at all.
- What's left is presumably the reverberant tail of the news, which the chip's short echo filter doesn't reach, plus the voice-to-news ratio, which is still low even after cancellation.

Next:
- [x] Wake word rounds with the reference on vs off (above).
- [ ] Software echo canceller with a long filter (WebRTC AEC3 / speexdsp) offline on these recordings. Needs recordings with AGC off for a clean test.
- [ ] Combined with the 180 Hz high-pass (`HPFONOFF` 3, configured, not deployed yet).
- [ ] If the rounds work, a service on the satellite: it gets the stream URL and start time from HA/MA whenever the Sonos plays, plays the reference into the ReSpeaker, and keeps the lead in the window by correlating continuously.

## Score logging (deployed Nov 1)

- **LVA** (`pkgs/by-name/linux-voice-assistant/wake-word-scores.patch`, `--wake-word-score-floor`): reports every peak of each active wake word's score at or above the floor, detected or not, as a `wake_word_score` event. The event carries the peak score, the threshold, the duration, and how long ago the peak was. A peak ends when the score drops below the floor, or after 3 s at most.
- **Activation log** (`lva-activation-log`):
  - every peak goes to `/var/lib/lva-activation-log/scores.jsonl` (time, word, score, threshold, `above_threshold`, duration, audio);
  - peaks at or above `recordAbove` also get a WAV, from 4 s before to 1.5 s after the peak: `<day>/<HHMMSS.mmm>_<word>_<score>.wav`;
  - activations in `activations.jsonl` now carry their `score`.
- **Settings:** `services.linux-voice-assistant.activationLog.scoreFloor = 0.05` and `recordAbove = 0.2` (the module's defaults).

## Evaluation, Nov 1 – 11

Data: 1223 activations since Oct 27, 7282 score peaks since Nov 1, 3679 clips (~900 MB). The trigger moment (1.5–4.8 s into each clip) was transcribed with parakeet on SRV-VOICE. Media context comes from HA history (`media_player.living_room`, `media_player.lg_c4`), which only goes back to Nov 1.

Activations per day, by threshold period ("ok" means HA did something sensible with the command):

| Period | Computer ok | Computer false | Alexa ok | Alexa false |
|---|---|---|---|---|
| Nov 1–7, C 0.8 / A 0.5 | 3.8 | 31.3 | 12.1 | 21.6 |
| Nov 7–10, C 0.9 / A 0.6 | 0.9 | 15.8 | 11.1 | 23.1 |
| Nov 10–11, C 0.8 / A 0.8 | 1.8 | 30.1 | 15.9 | 8.8 |

- **The spike of the last days is Computer**, back at 0.8 since Nov 10. It produces ~30 false wakes a day and is barely used anymore (you switched to Alexa).
- **Two kinds of false wakes:**
  - **TV speech** (mostly English, LG C4 on): the transcript is random speech, and HA answers "nicht verstanden".
  - **No speech at all** (Computer 150, Alexa 101): the transcript is empty, and the pipeline runs into the STT timeout after 15 s. These happen all day and night, in a quiet room (median 53 dB vs 63–66 dB for real wakes), and are bass-heavy (0–300 Hz +25 dB over 1–3 kHz).
- **The high-pass doesn't help.** Offline, 125 Hz, 180 Hz and 180 Hz 4th-order high-passes leave the no-speech triggers unchanged (Computer 140 → 140 of 150 above 0.8). The model reacts to the sound itself, not the bass. `HPFONOFF` 3 is harmless, but it isn't the fix.
- **Threshold sweep (offline, best of 3 alignments):**
  - Computer can't be separated: at 0.99 it still has 36/150 no-speech and 13/54 TV triggers, and already loses 6/31 real ones.
  - Alexa at 0.9: 75/98 real, 15/101 no-speech, 13/54 TV. At 0.95: 57/98, 6/101, 10/54.
  - Caveat: real attempts that never fired aren't in these numbers.
- **Activation log:** `pipeline_error` was always logged with `error: null`. LVA emits the event without the reason its docs promise. This is fixed in `wake-word-event-data.patch` (not deployed).

Training material:
- **Real utterances** (transcript contains the word, deduplicated across activation and score clips):
  - Alexa 244, spread evenly over the 15 days. Only 33 of them are near misses (score clips without activation).
  - Computer 189, mostly Oct 27 – Nov 1.
  - Many clips hold the word several times ("Alexa, Alexa").
- **Hard negatives:** ~600 false-wake clips (TV, no-speech), plus all score clips with no wake word in the transcript.
- **Enough for:** a real-voice test set, and real positives and room negatives mixed into a microWakeWord training run on generated (Piper) samples. **Not enough for:** training on real recordings alone.
- **Missing:**
  - attempts that never reached 0.2 (no clip at all);
  - continuous room audio to measure false wakes per hour of TV and music, the number that matters for a new model.

### Repeated tries, gain, knocks (Nov 11)

- **Repeated tries score lower because of the microWakeWord frontend, not LVA.** LVA's 2 s refractory only applies after an actual wake.
  - The test: 97 peaks from clips with the word said several times, re-scored with a fresh frontend and model started 1.8 s before each peak.
  - The result: +0.13 on average, and 28/92 tries gain more than 0.2 (e.g. 0.43 → 1.0, 0.39 → 0.96).
  - Resetting only the model changes nothing (+0.00). Started 3 s before the peak, the gain shrinks (+0.06).
  - Control: single tries gain nothing from a fresh start (+0.02, 1/40).
  - So the frontend's noise estimate adapts to your own voice for a few seconds and then subtracts it. This matches the "wait 5 s" experience.
  - Workaround: say the word once, and pause about 3 s before retrying.
  - A custom model trained with tries in quick succession, or a frontend with a faster noise estimate (would need retraining), could fix it properly.
- **Workarounds, simulated offline** (Alexa, threshold 0.8; "tries" = 37 clips with the word said at least twice; "near misses" = 250 score clips 0.2–0.8 without the word in the transcript):
  - **Second chance** (threshold 0.5 for 6 s after a peak of 0.3–0.8): 1 try earlier, so useless. The tries that confuse the frontend mostly score below 0.3, so there's no near miss to react to.
  - **Fresh detector after a near miss:** 3/37 earlier. Same reason.
  - **Rolling fresh detectors** (a new frontend and model every 1 s, each counting from 1 s to 3 s after its start, i.e. 2–3 extra instances running at once):

    | Threshold of the extra detectors | Tries detected (now 25/37) | Near misses triggering (now 6/250) |
    |---|---|---|
    | 0.8 | 35 | 32 |
    | 0.9 | 32 | 11 |
    | 0.95 | 31 | 8 |
    | 0.97 | 30 | 7 |

  - 0.95 looks like the sweet spot. The near-miss set is pre-selected, so before building it, check the false wakes per hour on the room recording.
- **Gain:** the chip's AGC runs up to 31.6× (AGCMAXGAIN, ~30 dB) toward −46 dBFS. In a quiet room it sits at 16–27×.
  - Turning clips down by 6/12/18 dB offline barely changes the scores (Computer no-speech 34/33/32/25 of 40; Alexa real 30/29/28/25), because the frontend normalises the level.
  - The listening files sounded "dialled to 11" partly because each snippet was peak-normalised for listening.
- **Double knock:** the most common Computer no-speech trigger. Two sharp transients resemble "Com-pu-ter's" plosives. The source is unknown, and it also happens at night.

## Room recording (Nov 11 10:50 – Nov 12 07:00, first 20 h)

- **Method:** both models re-run over the whole recording, as on the satellite (one frontend per 10-minute file); Silero speech segments (4201, 5.0 h of speech); each transcribed by parakeet on SRV-VOICE. The ground truth is the transcript: a wake word "tried" when it opens the segment (40 Computer, 14 Alexa), "said" anywhere (TV included). Live threshold 0.8 until Nov 11 22:20, then 0.97 for both.
- **Replay accuracy:** at 0.97, 45 of 46 replay wakes are also in the activation log. Some live wakes aren't reproduced (the frontend's state differs at file starts).
- **Satellite activations in that time:** 88 (67 Computer, 21 Alexa). Only 28 Computer and 8 Alexa with the word said nearby; 39 and 13 likely false: evening TV (English, Italian, Ukrainian), and many with no speech at all (knocks).
- **Caught tries and false wakes per hour:**

  | Variant | Computer tries caught (of 40) | Computer false/h | Alexa tries caught (of 14) | Alexa false/h |
  |---|---|---|---|---|
  | threshold 0.8 | 22 | 2.1 | 8 | 0.9 |
  | 0.9 | 21 | 1.8 | 4 | 0.5 |
  | 0.95 | 19 | 1.7 | 1 | 0.25 |
  | 0.97 (live since Nov 11 22:20) | 18 | 1.4 | 1 | 0.05 |
  | rolling fresh detectors, 0.97 | 30 | 3.7 | 2 | 0.2 |
  | rolling, 0.95 | 30 | 5.1 | 5 | 0.5 |
  | 0.97 + fresh detector for 8 s after a near miss (≥ 0.3) | 19 | 1.4 | 2 | 0.05 |

- **Conclusions:**
  - Both stock models catch about half of the tries at best. Alexa at 0.97 is practically off (1 of 14).
  - The rolling detectors do fix most retries (Computer 18 → 30 of 40), but more than double the false wakes. The near-miss gate keeps the false wakes but loses the gain: failed retries score below 0.3, there's no near miss to react to. Not worth building.
  - The real fix is a model trained on this room and these voices (plan step 5).
- **Training material** (scratchpad `room/train/`):
  - `positive/computer` (44), `positive/alexa` (16): 2.5 s clips of the tries; 5 recovered from false-wake candidates by a second transcription, 1 by listening (her "Alexa" at 20:33:15).
  - `hard_negative/` (219, all checked by listening): 3 s clips around false wakes (replay > 0.8, base or rolling), no wake word in their own transcript; 43 without any speech.
  - `negative_spans.json`: 20 h minus ±3 s around every wake word said, as background and for the false-wakes-per-hour check.
  - To review by ear: `review_positive.wav` / `review_hard_negative.wav` with the clip order in the matching `.tsv`.
- **Rerun with the full 48 h:** copy the new files to `room/rec/`, then `score.py`, `segment.py` (at most 3 in parallel), `stt.py`, `analyze.py`, `match.py`, `extract.py`.

## End-of-speech lag (Nov 11)

- **Who decides:** HA, in `assist_pipeline`. `pymicro_vad` gives a speech probability per 10 ms. With "aggressive", HA needs 0.25 s below 0.5, and the command must be at least 1 s.
- **Replay:** HA's segmenter, re-run offline on 157 recorded commands, lands within a median of 0.14 s of the real `stt_text` event.
- **Ground truth:** the earliest cut of the audio at which parakeet still returns the full transcript (binary search).
- **Lag from your last word:** 0.9 s median (p90 1.3 s) until the text reaches HA. Of that, 0.78 s (p90 1.13 s) is the end-of-speech detection.
- **Cause:** `pymicro_vad` keeps reporting speech after you stop. Its probability first drops to 0.5 or below a median of 0.55 s after the last word; it averages 0.78 in the first 200 ms after, and 0.60 at 400–600 ms.
  - A stricter cutoff (0.5 → 0.8) or a shorter silence (0.1 s) only saves 0.1–0.2 s.
  - Less gain (−6/−12 dB) changes nothing.
- **Silero VAD** (pysilero-vad 3.4, 0.2 ms per 32 ms chunk):
  - its probability falls a median of 0.22 s after the last word;
  - with 0.3 s silence and threshold 0.35, the lag is 0.50 s median (p90 0.79 s); with 0.4 s silence, 0.61 s (p90 0.91 s).
  - Cut check against the full transcript: 9 more of 157 transcripts change than with `pymicro_vad`. A few are real clipped endings ("Strahler aus" → "strahlungs", "Wetter" → "vetchar", a mid-sentence pause); the rest is STT noise or TV.
- **Possible way:** LVA runs Silero on the streamed audio and sends `VoiceAssistantAudio(end=True)`. HA's esphome satellite treats that as a stop (not an abort) and runs STT right away, and HA's own VAD stays as the fallback.

## Plan

1. **After 1–2 days:** count peaks in `scores.jsonl` below and above 0.2, per word and time of day. Adjust `recordAbove` (and possibly `scoreFloor`) to what's worth keeping.
2. **Ignored activations:** look for peaks with `above_threshold: true` but no activation within ~1 s. If there are any, find out why LVA ignored them: pipeline still active, refractory period, mute, or a bug.
3. **Real attempts vs threshold:** for real attempts, check where the live scores land.
   - Mostly 0.5–0.95: the model is the problem. Lower the threshold, switch the model, or train your own (step 5).
   - About 0.99, but with misses that have no peak at all: the voice isn't reaching the model (masking, placement). Go back to the chip and placement items in the voice ToDo.
4. **Collect for training:**
   - **Archive:** copy audio and logs to the NAS before the 30-day retention deletes them.
   - **Labels:** real or false wake, and speaker. A small labelling page for listening and tagging clips.
   - **Undetected misses:** a "missed it" button in HA that saves the last ~10 s from a rolling buffer, for attempts that never reach the floor.
   - **Room background:** optional random short snippets of living-room audio as negatives. Privacy decision first.
   - **Recording session:** a planned session per voice and position, with TV and music on (reuse the Oct 26 protocol).
5. **Custom wake word** (detailed in "Wake word — Training plan.md"): train a microWakeWord model on generated samples plus these recordings. Use the false wakes as hard negatives, and consider a smaller stride. Compare it with the current models on the recorded protocol.
