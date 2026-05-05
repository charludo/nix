{ lib, config, ... }:
let
  cfg = config.hass.voice;
in
{
  options.hass.voice = {
    intents = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      description = ''
        Conversation intents keyed by name; values are sentence-pattern
        strings. Slot patterns ({slot} or {slot:list}) require Hassil-
        compatible syntax — slot lists must already exist in HA's
        loaded intents pack or be defined in your conversation YAML.
      '';
      example = lib.literalExpression ''
        {
          WetterHeute = [
            "Wie ist das Wetter (heute|jetzt|gerade)"
            "Wie warm ist es draußen"
          ];
        }
      '';
    };

    intent_scripts = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "intent_script entries keyed by intent name";
      example = lib.literalExpression ''
        {
          WetterHeute.speech.text = "Aktuell sind es {{ states('sensor.foo') }} Grad.";
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
    ];

    services.home-assistant.config = lib.mkMerge [
      (lib.mkIf (cfg.intents != { }) {
        conversation.intents = cfg.intents;
      })
      (lib.mkIf (cfg.intent_scripts != { }) {
        intent_script = cfg.intent_scripts;
      })
    ];
  };
}
