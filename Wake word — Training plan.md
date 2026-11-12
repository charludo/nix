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

## Time

- Download: depends on the line; overlaps with steps 1–4.
- Synthetic clips: wakesmith says 3–30 clips/s on CPU; a few thousand per word, minutes to about an hour. Pocket TTS on SRV-VOICE: about real time per voice, all voices in roughly the same range.
- Training: per README, ~7 min per 20k steps on 12 CPU threads, a full standard run ~15 min on a mid-range NVIDIA GPU. Expect 0.5–1 h per word for the first run on CPU, less later, and several runs for tuning.
- Unmeasured; step 2/3 give the first real numbers.

## Open

- Archive the activation-log audio to the NAS before retention deletes it (from Nov 26). Training depends on it.
- Room recording: continues for 1–2 weeks as `room-recording-nix` (satellite config, takes over from the transient 48 h unit), then retrain with the current synthetic clips plus the new room data; day 1 stays the test set. ~1.2 GB a day; move files to hub in between.
- Privacy: the recordings contain conversations. They stay on hub (and the NAS archive); the wake word models contain no audio.
