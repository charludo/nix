{
  lib,
  linkFarm,
  writeText,
}:
let
  # Our own microWakeWord models, trained with wakesmith v0.4.8 on the living
  # room: German Piper and Pocket TTS voices plus real tries and false wakes
  # from the satellite (see "Wake word — Training plan.md"). Own ids, so they
  # don't shadow LVA's built-in `alexa`.
  #
  # probabilityCutoff is only the default: once a sensitivity is set on the
  # device page in Home Assistant, LVA uses that instead (per wake word slot).
  # Cutoffs: set per model on labelled room recordings it never trained on
  # (day 1 + Nov 13-15, 92 h), for about 0.1 false wakes/h.
  models = {
    computer_wohnzimmer = {
      name = "Computer (Wohnzimmer)";
      # v5 (Nov 17, run v5nw8-c6: negatives weighted 8x), best of 16 runs:
      # 99/103 tries at 0.08 false wakes/h, Marie 7/9 (v4-c5 at 0.995:
      # 97/103, Marie 7/9, 0.05/h). Usable from 0.92 (99/103, 0.09/h) to
      # 0.97 (94/103, 0.08/h); 0.98 gives 92/103 at 0.04/h.
      probabilityCutoff = 0.95;
    };
    alexa_wohnzimmer = {
      name = "Alexa (Wohnzimmer)";
      # v5 (Nov 17, run v5nw8-c4: negatives weighted 8x), best of 16 runs:
      # 31/33 tries at 0.09 false wakes/h, Marie 13/13 (v4-c17 at 0.97:
      # 31/33, Marie 12/13, 0.10/h). Counts after the Nov 17 word check.
      probabilityCutoff = 0.95;
    };
  };

  # microWakeWord's model manifest, as wakesmith exports it.
  manifest =
    id: m:
    writeText "${id}.json" (
      builtins.toJSON {
        type = "micro";
        wake_word = m.name;
        author = "wakesmith";
        website = "https://github.com/HuskerMinion/wakesmith";
        model = "${id}.tflite";
        trained_languages = [ "de" ];
        version = 2;
        micro = {
          probability_cutoff = m.probabilityCutoff;
          sliding_window_size = 5;
          feature_step_size = 10;
          tensor_arena_size = 30000;
          minimum_esphome_version = "2024.7.0";
        };
      }
    );
in
(linkFarm "wohnzimmer-wake-words" (
  lib.concatLists (
    lib.mapAttrsToList (id: m: [
      {
        name = "${id}.tflite";
        path = ./. + "/${id}.tflite";
      }
      {
        name = "${id}.json";
        path = manifest id m;
      }
    ]) models
  )
)).overrideAttrs
  (old: {
    meta = (old.meta or { }) // {
      description = "Own microWakeWord models for \"Computer\" and \"Alexa\" in the living room, for Linux-Voice-Assistant";
      # Trained with wakesmith (PolyForm Noncommercial) on non-commercial
      # negative datasets: home use only.
      license = lib.licenses.unfree;
    };
  })
