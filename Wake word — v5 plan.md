# Wake word — v5 plan

Goal: next batch of "Computer (Wohnzimmer)" and "Alexa (Wohnzimmer)", comparable 1:1 with v4.

## Test set (unchanged from v4)

- Room day 1 (Nov 11 10:50 – Nov 12 07:00) + Nov 13–15, 92 h. Never trained on.
- Tries: Computer 103 (Marie 9), Alexa 35 (Marie 14), before the corrections below.
- Only change: word-check corrections that fall on these days (removed entries count as neither try nor false wake).

## Training data

v4 data (copied, never edited in place), plus:

- **New tries:**
  - live7 (Nov 16 18:37 – Nov 17 07:37);
  - unlabelled-wake gaps: Nov 16 09:47–18:37 and Nov 12 07:00–14:51 (26 tries).
- **New hard negatives:**
  - live7 clips labelled "not a try": live near misses ≥ 0.35 and every comparison model's peak ≥ 0.9, about 256;
  - 3 gap misfires.
- **Room noise pool:** plus background from Nov 16 and live7. No audio from test days.
- **Corrections:** the 16 word-check removals (`ws2/word_fixes.json`) applied to every pool.
- **Unchanged:** the unreviewed Computer log negatives (about 90%) stay. Their review is postponed.

## Recipe

- wakesmith 0.4.8 with the local trainer patch:
  - weight averaging over the last 30%, BatchNorm re-estimated (`WAKESMITH_FINAL=swa`);
  - 20k steps, constant LR 0.001.
- **Room-noise augmentation:** the room's own background next to MUSAN (`WAKESMITH_EXTRA_NOISE`).
- **Real clips:** copies at default; Marie's clips about 5×.
- **Alexa only:** `partial_weight` 1.0.
- **Negative weight (decided Nov 17):** `WAKESMITH_NEG_WEIGHT` 4, plus an 8× arm. The weight is per clip; wakesmith's own `negative_class_weight` only scales whole batches and has no effect under Adam.
  - ×4 on v4 data at window 5 left far fewer false wakes no threshold can remove: at 0.995, Computer median 3.5 instead of 12, Alexa 2 instead of 7.5.
  - Every run reached 0.1/h, at thresholds of 0.98–0.99 (Computer) and 0.95–0.985 (Alexa) instead of 0.995.
  - Tries about the same: best runs 97/103 and 31/33.
- **Not used:** `house_rirs` (claps), `finetune_steps`, fewer steps, LR decay, ensembles, window 10.

## Runs

- Per word: 8 runs at negatives ×4 + 8 runs at ×8 = 16, each with its own random seed.
- One CCX63 per word, 6 runs in parallel: 3 waves of about 20 min, so about 1 h plus scoring.
- No room-noise control (decided Nov 17): on v1's data, without room noise, 8 of 9 Computer runs were already as hot as v4.

## Selection and evaluation

- Per run: lowest threshold with ≤ 0.1 false wakes/h on the test set (also report 0.2/h), at window 5.
- Pick: most tries caught (ties: fewer false wakes, higher threshold).
- Report, all against the repo models (`alexa-v4-c17` @0.97, `computer-v4-c5` @0.995) and the v4 candidates under the same rules:
  - median and worst run;
  - Charlotte vs Marie.
- Then: the repo gets the pick and threshold only if it's clearly better. Deploy is yours.

## Afterwards

- Satellite: check `preferences.json` after any cutoff change. Its Wake word 1/2 sensitivity overrides the manifest, and the slots follow LVA's own word order.
- Live check: a labelling round on the recordings after the deploy.

## Result (Nov 17)

- 32 runs, no failures. On the v4 test days, at window 5 and ≤ 0.1/h, the median run barely changed:
  - Alexa: 29/33 tries for ×4 and ×8, the same as v4 ×4.
  - Computer: 96/103 at ×4 and 95/103 at ×8 (v4 ×4: 95).
  - ×8 reaches the budget at lower thresholds (cooler) without losing tries.
- Into the repo:
  - Alexa: `alexa-v5nw8-c4` @0.95: 31/33, Marie 13/13, 8 false wakes (0.09/h). v4-c17 @0.97: 31/33, Marie 12/13, 0.10/h.
  - Computer: `computer-v5nw8-c6` @0.95: 99/103, Marie 7/9, 7 false wakes (0.08/h). v4-c5 @0.995: 97/103, Marie 7/9, 0.05/h. Usable from 0.92 to 0.97.
- Each pick is the best of 16 on the same test, so its edge is partly selection luck. The TV evenings that motivated v5 are training data now, so only the live check can show them.
