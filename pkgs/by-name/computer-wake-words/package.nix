{
  lib,
  fetchurl,
  linkFarm,
  writeText,
}:
let
  # Both upstreams name their model `computer`; LVA identifies wake words by
  # file name, so each gets its own id here.
  models = {
    computer_johnnyprimus = {
      name = "Computer (JohnnyPrimus)";
      author = "Leland Olney";
      website = "https://github.com/JohnnyPrimus/Custom_V2_MicroWakeWords";
      model = fetchurl {
        url = "https://raw.githubusercontent.com/JohnnyPrimus/Custom_V2_MicroWakeWords/2987c5ae4e4c8e7ac277bdede0904d99b4ed477a/models/computer/computer.tflite";
        hash = "sha256-ukjdgd7seOvVopTVFd69reWUryZ6U+HrnbCi2YamXvw=";
      };
      probabilityCutoff = 0.66;
      tensorArenaSize = 25544;
    };
    computer_tatertotterson = {
      name = "Computer (TaterTotterson)";
      author = "Tater Totterson";
      website = "https://github.com/TaterTotterson/microWakeWords";
      model = fetchurl {
        url = "https://raw.githubusercontent.com/TaterTotterson/microWakeWords/022fd4bdf98a61570ce8fffa6fe52482e1629e9d/microWakeWordsV2/computer.tflite";
        hash = "sha256-X3GmMUKyBKFGQbB9prSL1/BXYK51Qm28B15gWFsDPuY=";
      };
      probabilityCutoff = 0.97;
      tensorArenaSize = 30000;
    };
  };

  # microWakeWord's model manifest, as shipped upstream next to each model.
  manifest =
    id: m:
    writeText "${id}.json" (
      builtins.toJSON {
        type = "micro";
        wake_word = m.name;
        inherit (m) author website;
        model = "${id}.tflite";
        trained_languages = [ "en" ];
        version = 2;
        micro = {
          probability_cutoff = m.probabilityCutoff;
          sliding_window_size = 5;
          feature_step_size = 10;
          tensor_arena_size = m.tensorArenaSize;
          minimum_esphome_version = "2024.7.0";
        };
      }
    );
in
(linkFarm "computer-wake-words" (
  lib.concatLists (
    lib.mapAttrsToList (id: m: [
      {
        name = "${id}.tflite";
        path = m.model;
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
      description = "Community microWakeWord models for \"computer\", for Linux-Voice-Assistant";
      license = [
        lib.licenses.asl20 # JohnnyPrimus
        lib.licenses.unfree # TaterTotterson states no license
      ];
    };
  })
