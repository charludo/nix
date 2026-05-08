{ lib, config, ... }:
let
  ha = lib.ha;

  areasWithClimate = lib.filterAttrs (
    _: a: a.temperatureEntity != null && a.humidityEntity != null
  ) config.hass.areas;

  intentName = areaName: "Temperatur_${ha.mkSlug areaName}";

  mkVoice = areaName: area: {
    name = intentName areaName;
    value = {
      sentences = [
        "Wie (warm ist es|ist die Temperatur|feucht ist es) im ${areaName}"
        "Welche [Temperatur|Luftfeuchtigkeit] (haben wir|ist) im ${areaName}"
        "Wie ist das Klima im ${areaName}"
      ];
      script.speech.text = ''
        Im ${areaName} sind es {{ (states('${area.temperatureEntity}') | float | round(1) | string).replace('.', ',') }} Grad bei {{ states('${area.humidityEntity}') | float | round(0) | int }} Prozent Luftfeuchtigkeit.
      '';
    };
  };
in
{
  hass.voice = lib.mapAttrs' mkVoice areasWithClimate;
}
