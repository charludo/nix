{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.hass.voice;
  yamlFormat = pkgs.formats.yaml { };

  intents = removeAttrs cfg [
    "defaultLanguage"
    "extraConfig"
  ];

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
        description = ''
          Sentence patterns for this intent. Patterns may reference
          Hassil expansion rules (``<rule>``), built-in HA slot lists
          (``{name}``, ``{area}``, ``{timer_hours:hours}``), or custom
          slot lists declared via the sibling ``lists`` option
        '';
      };
      script = lib.mkOption {
        type = lib.types.nullOr lib.types.anything;
        default = null;
        description = ''
          ``intent_script`` body for this intent — usually
          ``{ speech.text = ...; action = [ ... ]; }``
        '';
      };
      language = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        defaultText = lib.literalExpression "config.hass.voice.defaultLanguage";
        description = "Language code; falls back to ``hass.voice.defaultLanguage``";
      };
      lists = lib.mkOption {
        type = yamlFormat.type;
        default = { };
        description = ''
          Hassil slot lists merged into this language's custom_sentences
          file. Supports ``{ values = [...]; }``, ``{ wildcard = true; }``,
          and ``{ range.from = N; range.to = M; }``
        '';
      };
      expansionRules = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Hassil expansion rules merged into this language's custom_sentences file";
      };
      responses = lib.mkOption {
        type = yamlFormat.type;
        default = { };
        description = "Hassil ``responses`` merged into this language's custom_sentences file";
      };
    };
  };
in
{
  options.hass.voice = lib.mkOption {
    default = { };
    description = ''
      Voice intents. Set ``hass.voice.<IntentName>`` to an attrset with
      ``sentences`` and/or ``script`` (plus optional ``language``,
      ``lists``, ``expansionRules``, ``responses``). All intents are
      grouped by language and emitted as a single
      ``custom_sentences/<lang>/nix.yaml`` file
    '';
    type = lib.types.submodule {
      freeformType = lib.types.attrsOf intentType;
      options = {
        defaultLanguage = lib.mkOption {
          type = lib.types.str;
          default = "en";
          description = "Fallback language for intents that don't set ``language``";
        };
        extraConfig = lib.mkOption {
          type = lib.types.attrsOf yamlFormat.type;
          default = { };
          description = ''
            Extra top-level keys merged into the per-language
            custom_sentences file, keyed by language code. Use for
            things like ``skip_words`` that apply to the whole file
            rather than a single intent
          '';
          example = lib.literalExpression ''
            { de.skip_words = [ "bitte" "mal" ]; }
          '';
        };
      };
    };
  };

  config = {
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

    systemd.tmpfiles.settings = lib.mkIf (intents != { }) {
      "10-hass-custom-sentences"."${config.services.home-assistant.configDir}/custom_sentences" = {
        "L+".argument = "${sentencesDir}";
      };
    };
  };
}
