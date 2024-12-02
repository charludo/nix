{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.hass.voice;
  yamlFormat = pkgs.formats.yaml { };

  langOf = i: if i.language != null then i.language else cfg.defaultLanguage;
  languages = lib.unique (lib.mapAttrsToList (_: langOf) cfg.intents);
  yamlByLang = lib.genAttrs languages (
    lang:
    let
      forLang = lib.filterAttrs (_: i: langOf i == lang) cfg.intents;
      intents = lib.mapAttrs (_: i: { data = [ { sentences = i.sentences; } ]; }) (
        lib.filterAttrs (_: i: i.sentences != [ ]) forLang
      );
      mergeField =
        field:
        lib.foldlAttrs (
          a: _: i:
          a // i.${field}
        ) { } forLang;
      lists = mergeField "lists";
      expansion_rules = mergeField "expansionRules";
      responses = mergeField "responses";
    in
    {
      language = lang;
    }
    // lib.optionalAttrs (intents != { }) { inherit intents; }
    // lib.optionalAttrs (lists != { }) { inherit lists; }
    // lib.optionalAttrs (expansion_rules != { }) { inherit expansion_rules; }
    // lib.optionalAttrs (responses != { }) { inherit responses; }
    // (cfg.extraConfig.${lang} or { })
  );

  sentencesDir = pkgs.runCommand "hass-custom-sentences" { } (
    "mkdir -p $out\n"
    + lib.concatStrings (
      lib.mapAttrsToList (lang: body: ''
        mkdir -p $out/${lang}
        cp ${yamlFormat.generate "nix.yaml" body} $out/${lang}/nix.yaml
      '') yamlByLang
    )
  );
in
{
  options.hass.voice = {
    intents = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            sentences = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Sentence patterns for this intent";
            };
            script = lib.mkOption {
              type = lib.types.nullOr lib.types.anything;
              default = null;
              description = "intent_script body for this intent, usually `{ speech.text = ...; action = [ ... ]; }`";
            };
            language = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = config.hass.voice.defaultLanguage;
              defaultText = lib.literalExpression "config.hass.voice.defaultLanguage";
              description = "Language code to use";
            };
            lists = lib.mkOption {
              type = yamlFormat.type;
              default = { };
              description = "Slot lists merged into this language's custom_sentences file";
            };
            expansionRules = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
              description = "Expansion rules merged into this language's custom_sentences file";
            };
            responses = lib.mkOption {
              type = yamlFormat.type;
              default = { };
              description = "Responses merged into this language's custom_sentences file";
            };
          };
        }
      );
      default = { };
      description = "Custom voice intent definitions";
    };

    defaultLanguage = lib.mkOption {
      type = lib.types.str;
      default = "de";
      description = "Fallback language for intents that don't set language";
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrsOf yamlFormat.type;
      default = { };
      description = "Extra top-level keys merged into the per-language custom_sentences file";
      example = lib.literalExpression ''
        { de.skip_words = [ "bitte" "mal" ]; }
      '';
    };

    sounds = lib.mkOption {
      type = lib.types.submodule {
        options = {
          acknowledge = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Path to the acknowledge sound file played on the satellite's target Sonos";
          };
          error = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Path to the error sound file played on the satellite's target Sonos";
          };
          timer = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Path to the timer finished sound file played on the satellite's target Sonos";
          };
          reminder = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Path to the reminder sound file played on the satellite's target Sonos";
          };
          alarmclock = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Path to the alarmclock sound file played on the satellite's target Sonos";
          };
          duck = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Path to near-silent audio file used to trick the satellite's target Sonos into ducking the audio during STT recoginition";
          };
        };
      };
      default = { };
      description = "Sound files played on the satellite's target Sonos";
    };
  };

  config = lib.mkIf (cfg.intents != { }) {
    services.home-assistant.extraComponents = [
      "wyoming"
      "assist_pipeline"
      "conversation"
      "intent_script"
      "todo"
    ];

    services.home-assistant.config.intent_script = lib.mapAttrs (_: i: i.script) (
      lib.filterAttrs (_: i: i.script != null) cfg.intents
    );

    systemd.tmpfiles.settings."10-hass-custom-sentences" = {
      "${config.services.home-assistant.configDir}/custom_sentences"."d" = {
        mode = "0755";
        user = "hass";
        group = "hass";
      };
    }
    // lib.listToAttrs (
      lib.concatMap (lang: [
        {
          name = "${config.services.home-assistant.configDir}/custom_sentences/${lang}";
          value."d" = {
            mode = "0755";
            user = "hass";
            group = "hass";
          };
        }
        {
          name = "${config.services.home-assistant.configDir}/custom_sentences/${lang}/nix.yaml";
          value."L+".argument = "${sentencesDir}/${lang}/nix.yaml";
        }
      ]) languages
    );

    system.activationScripts.hassCustomSentencesMigrate = {
      text = ''
        if [ -L ${config.services.home-assistant.configDir}/custom_sentences ]; then
          rm ${config.services.home-assistant.configDir}/custom_sentences
        fi
      '';
      deps = [ ];
    };
  };
}
