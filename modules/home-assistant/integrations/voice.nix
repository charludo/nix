{ lib, pkgs, config, ... }:
let
  cfg = config.hass.voice;
  haDir = config.services.home-assistant.configDir;
  yamlFormat = pkgs.formats.yaml { };

  sentencesDir = pkgs.runCommand "hass-custom-sentences" { } (
    lib.concatStringsSep "\n" (
      [ "mkdir -p $out" ]
      ++ lib.mapAttrsToList (name: spec: ''
        mkdir -p $out/${spec.language}
        cp ${yamlFormat.generate "${name}.yaml" spec} $out/${spec.language}/${name}.yaml
      '') cfg.custom_sentences
    )
  );
in
{
  options.hass.voice = {
    intents = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      description = ''
        Conversation intents keyed by name; values are sentence-pattern
        strings. Patterns may reference Hassil expansion rules (``<rule>``)
        and slot lists (``{list}`` or ``{list:capture}``) — either built
        into HA's language pack or declared in ``hass.voice.custom_sentences``.

        Goes via HA's ``conversation.intents`` YAML key — convenient but
        cannot reference custom lists/rules. For those, use
        ``hass.voice.custom_sentences``.
      '';
      example = lib.literalExpression ''
        {
          WetterHeute = [
            "Wie ist das Wetter (heute|jetzt|gerade)"
          ];
        }
      '';
    };

    intent_scripts = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "intent_script entries keyed by intent name";
    };

    custom_sentences = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        freeformType = yamlFormat.type;
        options.language = lib.mkOption {
          type = lib.types.str;
          description = "Language code (e.g. \"de\"). Determines the directory the file lands in.";
        };
      });
      default = { };
      description = ''
        Hassil ``custom_sentences/<lang>/<name>.yaml`` files. The full
        Hassil document format is supported: ``intents`` (with ``data``
        blocks), ``lists`` (text/range/wildcard), ``expansion_rules``,
        ``responses``, ``skip_words``. Files are written to
        ``${haDir}/custom_sentences/<language>/<name>.yaml``.

        Use this route when patterns need custom slot lists,
        wildcards, or expansion rules — those don't work via
        ``hass.voice.intents`` because HA's strict ``conversation:``
        schema rejects ``lists``/``expansion_rules`` keys.
      '';
      example = lib.literalExpression ''
        {
          einkauf = {
            language = "de";
            intents.Einkauf_Add.data = [{
              sentences = [ "Setze {item} auf die Einkaufsliste" ];
            }];
            lists.item.wildcard = true;
          };
        }
      '';
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

    services.home-assistant.config = lib.mkMerge [
      (lib.mkIf (cfg.intents != { }) {
        conversation.intents = cfg.intents;
      })
      (lib.mkIf (cfg.intent_scripts != { }) {
        intent_script = cfg.intent_scripts;
      })
    ];

    systemd.tmpfiles.settings = lib.mkIf (cfg.custom_sentences != { }) {
      "10-hass-custom-sentences"."${haDir}/custom_sentences" = {
        "L+".argument = "${sentencesDir}";
      };
    };
  };
}
