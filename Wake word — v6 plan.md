# Wake word — v6 plan

Goal: fewer false wakes during TV, and better recall for Marie, on top of v5's recipe:
- weight averaging;
- 20k steps;
- room noise;
- negatives weighted ×8;
- window 5.

These changes are independent of collecting more training or test material.

## 3. Synthetic Marie (and Charlotte)

- Problem:
  - Marie has 9 Computer test tries.
  - In training she is a few dozen real clips, each copied about 5×. The model sees her voice, but not her variation.
- Plan:
  - Clone her voice with Pocket TTS from a handful of clean tries plus ordinary speech from the room recordings, with her OK.
  - Generate about 2,000 positives per word: varied pace, emphasis, distance and noise, and phrases with command continuations ("Computer, Licht aus").
  - Same for Charlotte at about half the amount, so the model doesn't lean towards Marie.
  - Generate the same voices saying confusable words and sentences, as negatives. Otherwise "Marie's voice" itself becomes a wake cue.
- Check: Marie's tries on the test days stay the headline number. Charlotte's must not drop.
- Risk: cloned voices sound cleaner than the satellite mic. Run them through the same augmentation (room noise, RIRs) as all synthetic clips.

## 5. Automatic hard-negative mining

- Problem: hard negatives so far come from hand-labelled live rounds. That's slow, and it only covers moments a deployed model already woke on.
- Plan, per round:
  1. Score all room audio outside the test days with the current pick and 2–3 other strong runs.
  2. Every peak ≥ 0.5 that has no wake word in the Parakeet transcript (±4 s) and is more than 10 s from any labelled try becomes a negative candidate.
  3. Only the uncertain ones go to a labelling page: transcript contains a near-variant (Kompott, Alexander…), or there's no transcript at all.
  4. Train, rescore, repeat. Two rounds per v6 batch.
- Guard: never mine from the test days. Cap the share of mined clips per day, so one loud evening doesn't dominate.

## 6. A larger model

- Today:
  - wakesmith's fixed microWakeWord MixedNet: first conv 32 filters, four blocks of 64 pointwise filters, kernels [5] [7,11] [9,15] [23], stride 3;
  - 62 KB file;
  - `tensor_arena_size` 30000 hard-coded in the manifest.
- The architecture is hard-coded in `wakesmith/mww.py` (`MODEL_ARGS`). Plan:
  - Patch it, like the trainer patch: an env var `WAKESMITH_MODEL_ARGS` overriding the defaults. The torch port supports neither residual connections nor repeated blocks, so only filter counts and kernel sizes.
- Arms, 8 runs each, everything else as v5 ×8:
  - **M (wider):** pointwise 96,96,96,96; first conv 48. About 2× the compute.
  - **L (wider):** pointwise 128,128,128,128; first conv 64. About 4×.
  - Control: v5 ×8 itself, rerun with 8 new seeds on v6 data.
- Latency: same kernel sizes and stride, so the same receptive field and the same 30 ms step. Detection is not delayed, it only costs more compute per step.
- Before deploying an arm, on the satellite:
  - measure inference time and CPU;
  - set a real `tensor_arena_size` in the manifest (measured, not the 30000 default).

## 7. Real room acoustics

- Problem: augmentation uses generic room impulse responses. The claps (`house_rirs`) were too rough to use.
- Plan:
  1. Measure the living room: a log sine sweep from a speaker at 4–6 spots where people talk from (sofa, table, door, kitchen side), recorded by the satellite's own mic.
  2. Deconvolve to impulse responses, which also captures the mic's colouring.
  3. Add them to the augmentation next to the generic RIRs, about 50/50.
- Check: an arm with and without them, same seeds otherwise. Most of the effect should show on distant tries, which the test days have few of. Note per try whether it was said from far away.

## 8. Evaluation (applies to all of the above)

- Picks are made on one set of days and reported on a separate, untouched one. v5's winners were best-of-16 on the same days they were measured on.
- Hold back at least one TV evening from training as a test day.
- Report:
  - median and worst run per arm;
  - Marie and Charlotte separately;
  - false wakes during TV separately from other false wakes.

## Order and size

- One round with arms on the v6 data:
  - control;
  - +synthetic voices;
  - +synthetic voices, wider M;
  - +synthetic voices, wider L;
  - room RIRs once they're measured.
- 8 runs per arm. M and L train slower; L about 2–3× as long per run.
- Mining (5) runs before the round, and its clips go into every arm.
