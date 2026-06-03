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
  options.hass.voice = {
    intents = lib.mkOption {
      type = lib.types.attrsOf intentType;
      default = { };
      description = ''
        Voice intents. Set ``hass.voice.intents.<IntentName>`` to an
        attrset with ``sentences`` and/or ``script`` (plus optional
        ``language``, ``lists``, ``expansionRules``, ``responses``).
        All intents are grouped by language and emitted as a single
        ``custom_sentences/<lang>/nix.yaml`` file
      '';
    };

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

    sounds = lib.mkOption {
      type = lib.types.submodule {
        options = {
          acknowledge = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = ''
              Path to the sound file played on the satellite's target
              Sonos when an intent is marked with
              ``lib.ha.voice.acknowledgeAction``. Symlinked into
              ``<configDir>/www/sounds/<basename>`` and served as
              ``/local/sounds/<basename>``.
            '';
          };
          error = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = ''
              Path to the sound file played in place of the TTS when the
              pipeline returns an error response (``response_type =
              "error"``) other than ``no_intent_match``. Covers
              ``failed_to_handle``, ``no_valid_targets``, ``unknown``.
              ``no_intent_match`` is silenced unconditionally — no chime.
              Set null to fall back to relaying the synthesized error text.
            '';
          };
          timer = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Path to the sound file for timer-finished intents (currently unused).";
          };
          reminder = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Path to the sound file for reminder intents (currently unused).";
          };
          alarmclock = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Path to the sound file for alarm-clock intents (currently unused).";
          };
          duck = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = ''
              Path to a near-silent audio file fired as a Sonos
              announce on wake-word detection, so the speaker's native
              audioClip ducking lowers playback while the user
              interacts with the satellite. Should be a short clip
              (10–15s) — long enough to cover a typical interaction,
              short enough to recover gracefully if tts_relay fails to
              cancel it. Set null to disable wake-word ducking.
            '';
          };
        };
      };
      default = { };
      description = ''
        Per-category sound file paths played by tts_relay on the
        satellite's target Sonos when an intent's response carries a
        voice_effect card marker. Categories not listed (or set to
        null) fall back to relaying the synthesized TTS audio.
      '';
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

    # Symlink the Nix-generated nix.yaml per-language, not the whole
    # custom_sentences/ directory. Leaves <lang>/ writable so runtime
    # generators (e.g. mass-slot-lists) can drop sibling YAML files
    # next to nix.yaml — HA picks up every *.yaml in the directory.
    #
    # The `d` rules explicitly create the parent dirs as hass:hass so
    # the L+ rules don't traverse the root-owned dirs that `L+` would
    # otherwise auto-create — systemd-tmpfiles refuses to canonicalize
    # paths that cross an ownership boundary ("unsafe path transition").
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

    # One-shot migration from the previous layout, which symlinked the
    # whole custom_sentences/ directory into a Nix store path. tmpfiles
    # `L+` rules would try to write through that symlink and hit a
    # read-only filesystem; clear it before systemd-tmpfiles-setup runs.
    # Self-limiting: once the parent is a real directory the test fails
    # and the script is a no-op.
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
