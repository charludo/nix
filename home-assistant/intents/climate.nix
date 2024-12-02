{ lib, config, ... }:
let
  ha = lib.ha;

  areasWithClimate = lib.filterAttrs (
    _: a: a.temperatureEntity != null && a.humidityEntity != null
  ) config.hass.areas;

  intentName = areaName: "Temperatur${ha.mkTitleSlug areaName}";

  mkVoice = areaName: area: {
    name = intentName areaName;
    value = {
      sentences = [
        "Wie (warm ist es|ist die Temperatur|feucht ist es|warm haben wir es|feucht haben wir es) im ${areaName}"
        "Welche [Temperatur|Luftfeuchtigkeit] (haben wir|ist) im ${areaName}"
      ];
      script.speech.text = ''
        Im ${areaName} sind es {{ (states('${area.temperatureEntity}') | float | round(1) | string).replace('.', ',') }} Grad bei {{ states('${area.humidityEntity}') | float | round(0) | int }} Prozent Luftfeuchtigkeit.
      '';
    };
  };
in
{
  hass.voice.intents = lib.mapAttrs' mkVoice areasWithClimate;
}
