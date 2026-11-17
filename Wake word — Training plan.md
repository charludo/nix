# Wake word — Training plan

Own microWakeWord models for **Computer** and **Alexa**, trained on this room and our voices. Background and the numbers to beat: "Wake word — Observations and plan.md", section "Room recording".

## Decisions

- **Two models, one per word**, both active on the satellite as now. No per-speaker models: they would double the false wakes. Both voices go into each model.
- **Speaker labels** (me / her / unknown) for every real try: to weight her clips up in training, and to measure each of us separately. She activates the satellite much less reliably, and the data has few of her tries; a recording session with her is optional, not planned.
- **Trainer:** [HuskerMinion/wakesmith](https://github.com/HuskerMinion/wakesmith), a pinned release. It wraps microWakeWord training, takes own positives/negatives and held-out sets, and exports the int8 `.tflite` + `.json` that LVA loads. Non-commercial licence, as are the negative datasets: fine for home use.
- **Extra synthetic voices go into its own synthesis stage, not into `--positives`.** wakesmith likely treats user-supplied positives as the precious real data (weighting, held-out splits, review). Pocket TTS clips there would distort that. The 27 German Pocket TTS voices on SRV-VOICE should instead feed the same stage as its Piper voices, so they get the same filtering, augmentation and weight.
- **Retry problem** (frontend adapting to the voice, see the observations doc): not addressed now. Check after training whether it's still there; if so, train with pre-roll later.
- **Target to beat** (first 20 h of the room recording): Computer 18/40 tries at 1.4 false wakes/h (live threshold 0.97), 22/40 at 2.1/h (0.8). Alexa 1/14 at 0.05/h (0.97), 8/14 at 0.9/h (0.8).

## Steps

1. **Read wakesmith's source** (the pinned release) before running anything:
   - where and how it synthesises positives: the German voice list, the TTS backend interface, the cache layout; how to add a backend or voices (Pocket TTS over Wyoming, or pre-rendered clips placed where its own synthetic clips go);
   - how user positives are weighted against synthetic ones, and how per-clip weights could express speaker balance;
   - held-out handling (`HELDOUT.txt`, day splits) and the device-clip JSON (`at`, `device`, `model`, `score`);
   - training backend (TensorFlow or PyTorch) and its AMD path;
   - what `wakesmith setup` downloads, and whether it can download in the background while the rest goes on.
2. **Set up, in parallel:**
   - **Start the dataset download (~24 GB) first.** The connection is slow; everything else happens while it runs. Resumable, in the background.
   - Environment: container or FHS shell on hub (uv, Python 3.12); not packaged in nix, as it's a one-off tool. Disk: ~50 GB plus ~20 GB per project.
   - **Synthetic clips:** generate the Piper clips and the Pocket TTS clips (27 voices; speed, pitch and intonation variants, "Computer?" as a question) through the hook found in step 1. Pocket TTS runs on SRV-VOICE; HA's TTS stays usable meanwhile (one request at a time).
3. **AMD quick check** (≤ 30 min): RX 5600/5700 class (Navi 10, gfx1010). hub already has ROCm OpenCL, `/dev/kfd` and `renderD128` are accessible. gfx1010 is not on ROCm's support list, usually only works with `HSA_OVERRIDE_GFX_VERSION=10.3.0`, and can crash or compute wrong results (wakesmith warns about wrong results on some Intel drivers too). Test: the same quick run on GPU and CPU. Use the GPU only if it works and both agree. Otherwise CPU: per README ~7 min per 20k training steps on 12 threads.
4. **Label speakers** (done Nov 12): a small local web page on hub (scratchpad `label/`).
   - Plays each clip automatically, showing time and transcript. Keys: **←** Charlotte, **→** Marie, **↑** unknown, **x** misfire (not a try, e.g. TV), **↓** back, space to replay. Filter by label.
   - Clips: 620 real tries (activation-log wakes and near misses with the word in the transcript, room recording).
   - Result: Charlotte 589 (Alexa 345, Computer 244), Marie 23 (Alexa 18, Computer 5), unknown 8.
   - **Weighting:** Marie's clips go in ~5× as often as Charlotte's (wakesmith already uses each real clip 10× with different augmentation), about a sixth of the real positives. More would make the model learn her few clips by heart. Misfires stay out of training entirely.
   - Results are reported per speaker. A few more Computer tries from Marie (even 20) would help most, if she's up for it.
5. **Assemble the data:**
   - **Train:** activation-log real tries (positives) and false wakes (hard negatives), Oct 27 – Nov 10. Later runs add room recording day 2 (Nov 12 10:50 – Nov 13 10:50): tries, hard negatives, background. The first runs don't wait for it, nor for the speaker labels (they only add weighting).
   - **Held out for the test, never trained on:** room recording day 1 (Nov 11 10:50 – Nov 12 10:50). Both days have evening TV, so the test isn't easier than training.
   - Speaker weights from the labels, as step 1 allows.
6. **Train Computer** with a quick configuration first (does the pipeline run, are the numbers plausible), then the standard one. Then **Alexa**.
7. **Evaluate on the held-out day,** with our own scripts (`room/score.py` etc.) as well as wakesmith's report, so the numbers compare 1:1 with the table above:
   - tries caught, per speaker;
   - false wakes per hour, separately for quiet hours and TV hours;
   - shortcut check: real tries mixed under TV and music from the recording should still be caught; quiet negatives (night, quiet talk, knocks) should not fire;
   - pick the threshold from these.
8. **Deploy:** the models as a package in the repo (like `computer-wake-words`), added to `wakeWordDirs`; threshold per word from step 7. Possibly new Computer with stock Alexa first. The activation log keeps running; compare a week of live data with the evaluation.

## Progress (Nov 12)

- **Setup:** wakesmith v0.4.8 (commit a131ece), CPU-only venv in the scratchpad (`ws/venv`); data home `~/.local/share/wakesmith` (microWakeWord negative sets, MUSAN, MIT RIRs, German Piper voices; the openWakeWord-only 17 GB skipped). Piper retrained thorsten-medium on Nov 9; the pinned checksum matches revision `e7229f7d` of rhasspy/piper-voices.
- **AMD GPU:** out. RX 5600 XT (gfx1010) has no kernels in PyTorch's ROCm 7.2 build; with `HSA_OVERRIDE_GFX_VERSION=10.3.0` the GPU hung and Hyprland crashed. CPU is fast enough: quick test end to end in 10 min.
- **Real clips** (`ws/prepare.py` → `ws/data/<word>/{positives,negatives}`): cut so the clip ends where the word ends (wakesmith keeps a clip's last speech burst, which would otherwise be the command). The activation log keeps 4.0 s before the detection/peak; the word ends at 3.8–4.1 s, found per clip from the pause after it (95 %).
  - Training: Computer 228 (Charlotte 203, Marie 5×5), Alexa 421 (Charlotte 341, Marie 16×5). Held out: room day-1 tries (46 / 16).
  - Negatives: 1,638 activation-log false wakes and near misses ≥ 0.5 whose transcript has no wake word in any spelling ("Annexa", "Ale jaksa", "Алекса" were real tries and are positives now); handled commands excluded. Held out: the 219 room day-1 hard negatives.
- **Sound-alikes:** wakesmith's German suggestions are spelling variants pronounced like the word itself ("komputer"), and its Whisper filter needs a GPU. Replaced by real words (Kompott, Komponist, Kumpel, "kommt Peter" …; Alexis, Alessa, Alaska, "alles klar" …). Nothing starting with the wake word ("Computern", "Alexander"). The false-wake transcripts show no recurring trigger word: false wakes are arbitrary (mostly English TV) speech, covered by the real negatives.
- **Synthetic voices** (judged by listening):
  - Piper: keep the three Thorsten voices, Karlsson, Ramona, Pavoque; drop Kerstin and Eva K. espeak stresses "alexa" on the first syllable; "alekssa" gives a-LEK-sa (used for ¾ of the Piper Alexa clips).
  - Pocket TTS (27 voices, `POCKET_TTS_SEED=random` added to the sampling patch; a busy server answers a second request with nothing, so one request per server): plain "Computer" often has a hard P ("Kom-P-uter"); **"Compjuter?"** says "Kom-pju-ta". Plain "Alexa" is often cut to "Alex"/"Alexe"; a sentence after it ("Alexa. Mach das Licht an.", cut at the first pause) keeps the word whole. Every Pocket clip must transcribe as exactly the word.
  - Order trap: wakesmith fills the synthetic set voice by voice up to cumulative shares and counts existing clips first, so pre-placed clips starve the first voices. Piper is generated first, Pocket clips appended after.
- **Quick test** (Computer, 2,000 synthetic clips with the old Pocket set, 5,000 steps), streamed over the 20 h of room day 1 like the stock model:

  | Model | Threshold | Tries caught (of 40) | False wakes/h |
  |---|---|---|---|
  | stock | 0.97 | 18 | 1.39 |
  | stock | 0.8 | 22 | 2.14 |
  | quick test | 0.9 | 34 | 1.04 |
  | quick test | 0.97 | 31 | 0.75 |

  Scripts: `room/score_model.py` (stream a model over the recording), `room/compare.py <word> <models…>`.
- **Sound-alike check without a GPU:** wakesmith's Whisper check (drops sound-alike clips heard as exactly the wake word) only runs on a GPU. `ws/parakeet_check.py` does the same with parakeet on SRV-VOICE (~16 clips/s) and writes the verdicts in wakesmith's own format (`clips/whisper/negatives-parakeet.jsonl`), so with `check_negatives` on wakesmith leaves those clips out itself. `written_as` lists the transcriber's spellings of the word (Kompjuter, Aleksa, Алекса …).
- **Unattended sequence:** `ws/orchestrate.py` (log `ws/orchestrate.log`): per word, Piper half → parakeet check → Pocket half appended → quick test (`<word>-quick2`, 2,000 clips per class from the same data, 5,000 steps) → stream evaluation (`ws/eval-<project>.txt`) → standard run → stream evaluation. One training at a time.
- **First models** (Nov 12; standard runs, 20k steps, 3 candidates; exports in `~/.local/share/wakesmith/projects/<word>/export/microwakeword/`). Synthetic positives: Computer 12,500 Piper + 12,043 Pocket ("Compjuter" variants), Alexa 12,500 Piper + 8,782 Pocket (sentence-cut). Room day 1 (20.1 h, never trained on; wakesmith used half of its cut clips to pick the candidate):

  | Model | Threshold | Tries caught | False wakes/h |
  |---|---|---|---|
  | Computer stock | 0.97 | 18/40 | 1.39 |
  | Computer new | 0.90 | 40/40 | 0.60 |
  | Computer new | 0.97 | 40/40 | 0.45 |
  | Alexa stock | 0.80 | 8/14 | 0.89 |
  | Alexa stock | 0.97 | 1/14 | 0.05 |
  | Alexa new | 0.70 | 14/14 | 0.99 |
  | Alexa new | 0.95 | 13/14 | 0.30 |

  A try counts as caught when the score crosses the threshold during it (quick repeats 2–3 s apart fall into the 5 s refractory of the first detection but were heard). Day 1 has no Computer tries from Marie, so her rate is unmeasured.
- **Deployed** Nov 12 14:47 as `pkgs/by-name/wohnzimmer-wake-words` ("Computer (Wohnzimmer)", "Alexa (Wohnzimmer)"); thresholds 0.97 / 0.95, set in HA (the sensitivity belongs to the wake word slot; the manifest's `probability_cutoff` is only the fallback). Room recording continues as `room-recording-nix` in the satellite config (stops itself under 2 GB free).
- **First live window** (14:47–17:13, every moment labelled on a second page, scratchpad `label2/`):

  | Speaker | Word | Woke | Missed |
  |---|---|---|---|
  | Charlotte | Computer | 9 | 1 (quiet, 0.38) |
  | Charlotte | Alexa | 4 | 0 |
  | Marie | Alexa | 5 | 5 (0.0–0.4; once 0.94, then woke on the retry) |
  | misfire | Computer 3, Alexa 11 | 0 | – |

  - Misfires are mostly coughing, scoring 0.38–0.90: below the thresholds, so none woke. Don't lower the thresholds; use them as hard negatives in the next run.
  - Marie's misses are as loud as her hits and transcribe clearly as "Alexa"; the same phrase seconds apart scores 0.01 once and 1.0 the next time. Neither stride phase nor the preceding audio (Sonos reply) explains them: scored in isolation, they stay low.
  - **Likely cause: no pause after the word.** Charlotte says "Alexa; …" / "Computer? …"; Marie runs straight on ("AlexaStrahler an") and won't change that. Every training positive has a pause after the word (synthetic clips end at the word or at a sentence pause; real tries were cut at the word end). Cut after the word with room noise appended, two of her four clear misses score high (0.06 → 0.87, 0.75 → 0.99); the other two follow straight on a Sonos reply and couldn't be isolated cleanly. Likely, not proven.
  - **Sliding window size doesn't help** (`room/score_raw.py` keeps the raw outputs, `room/window.py` compares N = 1–5 on both days): Marie 5/10 at every N, even N = 1; smaller N only adds false wakes. Her raw outputs never get high, so the model seems to fire a moment after the word, once the quiet it always heard in training follows. Window stays at 5.
- **Next run, for Marie:**
  - Real tries cut 0.15–0.3 s after the word end instead of at it, so the start of the command is in the clip. Her run-on tries are the examples that matter.
  - Pocket TTS "Alexa mach das Licht an" (and Computer) without punctuation, cut shortly after the word; the cut point from the transcriber's word timings (still to check that parakeet gives them).
  - Charlotte's paused tries stay in. Post-deploy misfires (coughs) in as hard negatives.
- **Loud tries do worse** (Charlotte noticed quieter tries work better). New model's score vs. the try's level (loudest 0.5 s), day 1 plus the labelled post-deploy tries: below −30 dBFS 27/27 caught; −30…−20 about 9/10; −20…−15 6/7; above −15 dBFS 3/5 (two of them clipping). Cause, from the training setup (microWakeWord augmentation as wakesmith runs it): every clip gets a random gain of **−45…0 dB, never louder**, so the training speech is mostly far quieter than live speech. Sources before the gain: Piper median −18 dBFS, Pocket −30…−34, real tries −23…−25; after it the median is around −40 (Piper) to −56 (Pocket), and only ~7 % of Piper examples (~0 % of Pocket) are louder than −20 dBFS. Live tries are mostly −35…−15.
  - Also from the same code: each clip is placed **0.2 s before the end** of the training window (jitter 0.195–0.205 s), filled with background noise only. So the model learns to fire ~0.2 s after the word, after a stretch without speech: the mechanism behind Marie's run-on misses.
  - **The array's AGC adds to it.** XVF-3000 AGC on with chip defaults (our tuning doesn't touch it), read from the chip Nov 12 18:30: `AGCONOFF 1`, `AGCMAXGAIN 31.6` (+30 dB), `AGCGAIN 12.2` (+22 dB at that moment), `AGCDESIREDLEVEL 0.005`, `AGCTIME 0.98` s. In a quiet room it turns itself up, and a loud "Alexa" at the start of a sentence arrives before it can turn down (~1 s): the loudest tries clip (18:14:41, −14.5 dBFS, full scale, score 0.22; two of the five loudest on day 1).
    - Options, to compare in one experiment (values written to the chip directly, forgotten on replug; scores by loudness and false wakes per evening, as in the analysis above):
      1. **Lower ceiling:** AGC stays on, `AGCMAXGAIN` 4–6 (+12–15 dB instead of +30). Keeps some levelling for distant speech; a quiet room can no longer pump the gain up so far that a loud onset clips.
      2. **Off, fixed gain:** `AGCONOFF = 0`, `AGCGAIN` around 4 (+12 dB): a loud try would land around −24 dBFS instead of clipping, a quiet one around −48. Most predictable: level in = level out, which is what the training's gain augmentation assumes, and the model's own frontend (PCAN) already normalises level.
      3. Not worth trying: a faster `AGCTIME` (minimum 0.1 s). The word itself lasts ~0.5 s, so a fast AGC would pump during it and distort its envelope instead of preventing the clipping.
    - **Not now:** it changes the audio of the recording that's collecting material for the retrain. Run it together with the retrain and with **HPFONOFF 2 → 3** (see below): either change both first and record with the new settings, or retrain on the current settings and change them afterwards (the gain augmentation below should make the model less level-dependent either way).
  - Next run: bring all positive sources to one speech level first (Pocket sits 15 dB below Piper), then a gain range that matches live levels (about −50…−12 dBFS, some clipping via the existing TanhDistortion). Needs a small change to wakesmith's augmentation settings (`mww.py`, `_AUG`), as they aren't project options.
  - First collect more of Marie's tries from the running recording; label in batches (label2 page). Hold some of hers out, so her rate is measurable.

- **Live, Nov 12 18:17 – Nov 15 16:00** (70 h, room recording, all 311 clips labelled: wakes, transcript tries and live peaks ≥ 0.35; scratchpad `live3/room/label/`). Thresholds 0.97 / 0.95.

  | Speaker | Word | Woke |
  |---|---|---|
  | Charlotte | Computer | 45/52 (87 %); misses 0.55–0.96, 4 of 7 at 0.79–0.96 |
  | Charlotte | Alexa | 14/21 (67 %); misses 0.43–0.94 |
  | Marie | Computer | 10/16 (63 %); misses 0.00–0.94 |
  | Marie | Alexa | 17/28 (61 %); misses 0.00–0.90, five at 0.00 |

  - False wakes: 7 in 70 h (0.10/h): TV (Tagesschau, a podcast, English), night noise, "Yeah"/"I think". Coughs score 0.5–0.9 and almost never reach the threshold.
  - Threshold sweep (live scores only): Computer 0.93 catches 4 more tries for 2 more false wakes in 70 h (worth trying, set in HA); Alexa below 0.95 adds false wakes fast (0.90: 3 more tries, 9 more false wakes), keep.
  - Level confirms the loudness problem: above −15 dBFS (loudest 0.5 s) 3/10 woke, below −35 dBFS 12/13, in between 71/94. Marie is louder (6 of her 44 above −15 dBFS, 1 woke).
  - Labels: "misfire" = not a try (mostly never fired); only the 7 wakes are real false wakes. All are negatives for training, ≥ 0.5 hard negatives, no extra weight.
- **Next run, planned (Nov 15):** current mic settings (AGC/HPF experiment later, only if the retrain isn't enough). Held out: room day 1 again (Nov 11 10:50 – Nov 12 10:50), for a 1:1 comparison; everything else goes into training, including all of Marie's new tries. Her rate is then measured live afterwards, with a labelling round like this one as the baseline.
- **Run v2, Nov 15/16: no improvement; v1 stays.** Full report: `/tmp/claude-1000/-home-charlotte-Projekte-nix/10ecb331-4cf4-419e-884c-9b45f0c64a3b/scratchpad/ws2/REPORT.md`.
  - Ablations on v2 data: two cuts → word-end cut only → without gain patch → without background negatives. None was measurably better or worse than v1 on day 1.
  - **Main finding: seed noise.** v1 retrained twice on identical data, on the 70 h labelled recording:
    - Computer: 58/57/65 of 68 at 0.95, with false wakes from 0.06 to 0.37/h;
    - Alexa: 32/36/22 of 54.
    - Even at equal false-wake rates the spread is ±5 (Computer) and ±7 (Alexa) tries. That's bigger than any data effect we looked for.
    - wakesmith's pick among its 3 seeds (8 Alexa / 25 Computer clean clips, which all seeds pass) can't see it.
  - Fold test (v2a trained without each half of the labelled recording, tested on that half):
    - Computer is as good as v1 (60 vs 59/68 at ≤5 false wakes in 70 h).
    - Alexa is at the low end of the v1 seeds (26 vs 33/54 at ≤10).
    - No gain for Marie, despite 2–3× more of her clips.
  - Marie's failed Alexa tries are clean (SNR above 20 dB, better than Charlotte's). Pronunciation, not noise.
  - **Next, if we retrain again:** select the model, not the data. Train ~8 candidates, pick by streaming score on one labelled recording at equal false-wake rate, set its threshold there, and report on the other recording. Then try a heavier weight on real positives (Marie).

- **Runs v3/v4 and lever rounds, Nov 16: v4 is in the repo** (`pkgs/by-name/wohnzimmer-wake-words`: Alexa `alexa-v4-c17` @0.97, Computer `computer-v4-c5` @0.995; not deployed). Scratch files: `scratchpad/ws2/` (scripts, `select_*.txt`, `cands3/`, `cands4/`).
  - **Setup.** Training on two rented Hetzner CCX63 (one per word, 6 runs at a time, scoring on the same machine); recordings for scoring uploaded, models and score traces back to hub.
  - **Split.** Training: activation log, Nov 12, Nov 16. Selection: room day 1 + Nov 13–15 (92 h; Computer 103 tries, Marie 9; Alexa 35 tries, Marie 14). Every run gets its own threshold for ≤ 0.1 false wakes/h on the selection recordings; the pick is the run catching most there.
  - **Model selection (part 1).**
    - 9 runs on v1's data differ by ±5–10 tries at equal false-wake rate.
    - Picking by room score avoids the bad runs and was worth +3 to +7 Alexa tries.
    - A threshold per model is worth as much: v1 Computer at 0.905 instead of 0.97 catches 95 instead of 90 of 103.
    - Day 1 alone was too small and too untypical to pick on.
  - **Weight on real clips (part 2).** `real.sampling_weight` 2 is worse than 0: Alexa −4 tries on Marie's unseen session, and 4 of 16 Computer runs unusable. Kept at 0.
    - Marie's own data helps: on her unseen session the weight-0 runs catch 14.5 of her 22 tries, v1 10.
  - **Label hygiene.**
    - v1's 1,638 activation-log negatives were never reviewed (rule: no wake word in the transcript). Reviewed now: 16 Alexa tries were among them (about 4%); 0 of 164 Computer clips.
    - Since Nov 1 the log has two clips per wake: 439 duplicates removed.
    - Day-1 hard negatives: 2 tries in 219. Room background: 0 tries in 75 checked.
    - Removing the unreviewed negatives alone changed nothing measurable.
  - **Hard tries.** Of the 12 Alexa tries most runs miss: 4 overlapped (TV, music, people), 2 quiet/far, 5 clear, 1 mention (talking *about* Alexa: neither try nor false wake, neither positive nor negative).
  - **Room noise in training (v4) is the only lever with a gain so far.**
    - wakesmith's noise (MUSAN) has no speech or music. Adding the room's own background (TV, music, talk) as augmentation noise helped:
      - Alexa: median +1.3 to +1.8 tries;
      - overlapped hard tries caught twice as often;
      - no unusable runs.
    - v4 also uses only reviewed negatives, log duplicates removed, and the log-review tries as positives.
    - Result:
      - Computer v4: median 94/103, best 97 (v1 95). The first runs better than v1, but "hot" (11 of 24 never reach 0.1/h; the best need 0.995).
      - Alexa v4: median 26/35, best 31 (v1 23); Marie 11–12 of 14 (v1 8).
  - **Levers without gain** (12 runs each per word, against v4):
    - `partial_weight` 1.0: Computer −2 to −4 tries on the median, Alexa unchanged.
    - `finetune_steps` 10k: hotter (Computer: 1 of 12 usable at 0.1/h), not better.
    - `house_rirs` (10 clean claps, Nov 16 17:53, AGC off): like v4; the quiet/far tries are not caught more often.
    - An ensemble of the 3–5 best runs: no gain.
  - **Training is restless, a likely cause of the spread** (one full 20k log so far; curves of the 10k/15k runs being collected):
    - The validation score every 500 steps jumps between 0.28 and 0.89 without a trend, and the validation false wakes between 8 and 36/h.
    - The learning rate stays at 0.001 for all steps.
    - The exported model is the checkpoint with the best validation score: often a lucky spike (here step 18,500 of 20,000).
    - So no classic overtraining. Which checkpoint wins is largely chance, which would explain the spread between runs and the "hot" runs.
    - `finetune_steps` doesn't fix it, probably because the best checkpoint is still picked across both phases.
  - **Fix to test next.**
    - (1) Decaying learning rate (e.g. 0.001 → 0.0003 → 0.0001) and export of the last checkpoint instead of the best.
    - (2) Averaging the weights over the last 20–30 % of training (EMA/SWA).
    - Both need a small wakesmith patch. Expectation if the hypothesis holds: less spread between runs, fewer hot runs, the typical run at least as good as v4.
  - **Not reachable by training so far.** Quiet/far tries (microphone side: the AGC experiment). Marie's Computer: only ~25 of her tries in training, so a session from her is the most promising data lever.
- **Night of Nov 16 to 17: training fixes.** Full report: `scratchpad/ws2/REPORT-night.md`. The repo stays on v4.
  - **No overtraining.** 10k/15k steps make the models less hot but not better.
  - **Restless training confirmed.** Alexa's validation score jumps by 0.13–0.18 between checkpoints, and the exported "best" checkpoint is a lucky cool moment.
  - **Weight averaging over the last 30% of training (SWA, patched trainer) gives consistently better typical runs.** Alexa median 29/35 instead of 26, worst run 27 instead of 21; Computer worst run 90 instead of 85.
  - **"Hot" = saturation.** A few false wakes get the maximum score 0.996. A 10-step `sliding_window_size` instead of 5 halves them without costing tries; that's computed offline from the traces, exactly.
  - **partial / finetune / house_rirs add little on top of averaging.** Only partial makes Alexa slightly more consistent.
  - **The best of 24 averaging runs is about equal to the v4 picks at 0.1/h** (+1 Computer, −1 Alexa), and better at 0.2/h (+3 / +1).
  - **For future rounds:** use weight averaging, 8 runs per word, and window 10.
  - **Remaining gains:** data (Marie's Computer tries, live labelling, hard negatives) and the microphone (AGC).
  - **Mic note.** Claps right at the array clip at full scale even with AGC off and gain 4×. Temporary AGC changes go through `respeaker-tuning-apply` with `sudo` on the satellite; a reboot resets them.

- **High-pass filter is at 125 Hz, not 180 Hz.** The chip reads `HPFONOFF 2`, the config says 3: the tuning service was a plain oneshot, run only when the array appears on USB (last boot Nov 10, when the config still said 2), so the change to 3 never reached the chip. Everything recorded since Nov 10, all training material from the room and the post-deploy data, is at HPF 2. Fixed in `modules/nixos/respeaker-mic-array.nix` (Nov 12, not deployed): the service now stays active while the array is plugged in (bound to its device), so a deploy that changes the parameters reapplies them. After the first deploy with this change it still needs one reboot or replug before the device unit exists. The config is set back to `HPFONOFF = 2` (comment in `home-assistant/satellite/default.nix`), so a reboot doesn't change the recording conditions; switch to 3 together with the AGC experiment above.

## Time

- Download: depends on the line; overlaps with steps 1–4.
- Synthetic clips: wakesmith says 3–30 clips/s on CPU; a few thousand per word, minutes to about an hour. Pocket TTS on SRV-VOICE: about real time per voice, all voices in roughly the same range.
- Training: per README, ~7 min per 20k steps on 12 CPU threads, a full standard run ~15 min on a mid-range NVIDIA GPU. Expect 0.5–1 h per word for the first run on CPU, less later, and several runs for tuning.
- Unmeasured; step 2/3 give the first real numbers.

## Open

- Archive the activation-log audio to the NAS before retention deletes it (from Nov 26). Training depends on it.
- Room recording: continues for 1–2 weeks as `room-recording-nix` (satellite config, takes over from the transient 48 h unit), then retrain with the current synthetic clips plus the new room data; day 1 stays the test set. ~1.2 GB a day; move files to hub in between.
- Privacy: the recordings contain conversations. They stay on hub (and the NAS archive); the wake word models contain no audio.
