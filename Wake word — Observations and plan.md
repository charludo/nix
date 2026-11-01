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

## Score logging (deployed Nov 1)

- **LVA** (`pkgs/by-name/linux-voice-assistant/wake-word-scores.patch`, `--wake-word-score-floor`): reports every peak of each active wake word's score at or above the floor, detected or not, as a `wake_word_score` event. The event carries the peak score, the threshold, the duration, and how long ago the peak was. A peak ends when the score drops below the floor, or after 3 s at most.
- **Activation log** (`lva-activation-log`):
  - every peak goes to `/var/lib/lva-activation-log/scores.jsonl` (time, word, score, threshold, `above_threshold`, duration, audio);
  - peaks at or above `recordAbove` also get a WAV, from 4 s before to 1.5 s after the peak: `<day>/<HHMMSS.mmm>_<word>_<score>.wav`;
  - activations in `activations.jsonl` now carry their `score`.
- **Settings:** `services.linux-voice-assistant.activationLog.scoreFloor = 0.05` and `recordAbove = 0.2` (the module's defaults).

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
5. **Custom wake word:** train a microWakeWord model on generated samples plus these recordings. Use the false wakes as hard negatives, and consider a smaller stride. Compare it with the current models on the recorded protocol.
