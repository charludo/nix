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
  models = {
    computer_wohnzimmer = {
      name = "Computer (Wohnzimmer)";
      # Room day 1, 20 h: 40/40 tries, 0.45 false wakes/h.
      probabilityCutoff = 0.97;
    };
    alexa_wohnzimmer = {
      name = "Alexa (Wohnzimmer)";
      # Room day 1, 20 h: 13/14 tries, 0.30 false wakes/h.
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
