{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.hass.voice;
  yamlFormat = pkgs.formats.yaml { };

  intents = cfg.intents;

  intentList = lib.mapAttrsToList (
    name: i:
    {
      inherit name;
      language = if i.language != null then i.language else cfg.defaultLanguage;
    }
    // {
      inherit (i)
        sentences
        script
        lists
        expansionRules
        responses
        ;
    }
  ) intents;

  languages = lib.unique (map (i: i.language) intentList);

  mergeForLang =
    lang:
    let
      forLang = lib.filter (i: i.language == lang) intentList;
    in
    lib.foldl'
      (acc: i: {
        intents =
          acc.intents
          // lib.optionalAttrs (i.sentences != [ ]) {
            ${i.name}.data = [ { sentences = i.sentences; } ];
          };
        lists = acc.lists // i.lists;
        expansion_rules = acc.expansion_rules // i.expansionRules;
        responses = acc.responses // i.responses;
      })
      {
        intents = { };
        lists = { };
        expansion_rules = { };
        responses = { };
      }
      forLang;

  mkLangYaml =
    lang:
    let
      m = mergeForLang lang;
      extra = cfg.extraConfig.${lang} or { };
    in
    {
      language = lang;
    }
    // (lib.optionalAttrs (m.intents != { }) { inherit (m) intents; })
    // (lib.optionalAttrs (m.lists != { }) { inherit (m) lists; })
    // (lib.optionalAttrs (m.expansion_rules != { }) { inherit (m) expansion_rules; })
    // (lib.optionalAttrs (m.responses != { }) { inherit (m) responses; })
    // extra;

  sentencesDir = pkgs.runCommand "hass-custom-sentences" { } (
    lib.concatStringsSep "\n" (
      [ "mkdir -p $out" ]
      ++ map (lang: ''
        mkdir -p $out/${lang}
        cp ${yamlFormat.generate "nix.yaml" (mkLangYaml lang)} $out/${lang}/nix.yaml
      '') languages
    )
  );

  scripts = lib.mapAttrs (_: i: i.script) (lib.filterAttrs (_: i: i.script != null) intents);

  intentType = lib.types.submodule {
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
  };
in
{
  options.hass.voice = {
    intents = lib.mkOption {
      type = lib.types.attrsOf intentType;
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

  config = lib.mkIf (intents != { }) {
    services.home-assistant.extraComponents = [
      "wyoming"
      "assist_pipeline"
      "conversation"
      "intent_script"
      "todo"
    ];

    services.home-assistant.config = lib.mkIf (scripts != { }) {
      intent_script = scripts;
    };

    systemd.tmpfiles.settings = {
      "10-hass-custom-sentences" = {
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
    };

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
