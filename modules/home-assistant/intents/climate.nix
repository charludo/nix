{ lib, config, ... }:
let
  ha = lib.ha;

  # Areas with both temperature and humidity entities; one combined intent
  # per area, deriving names from the area key.
  areasWithClimate = lib.filterAttrs (
    _: a: a.temperatureEntity != null && a.humidityEntity != null
  ) config.hass.areas;

  intentName = areaName: "Temperatur_${ha.mkSlug areaName}";

  mkIntent = areaName: _: {
    name = intentName areaName;
    value = [
      "Wie (warm ist es|ist die Temperatur|feucht ist es) im ${areaName}"
      "Welche [Temperatur|Luftfeuchtigkeit] (haben wir|ist) im ${areaName}"
      "Wie ist das Klima im ${areaName}"
    ];
  };

  mkScript = areaName: area: {
    name = intentName areaName;
    value.speech.text = ''
      Im ${areaName} sind es {{ (states('${area.temperatureEntity}') | float | round(1) | string).replace('.', ',') }} Grad bei {{ states('${area.humidityEntity}') | float | round(0) | int }} Prozent Luftfeuchtigkeit.
    '';
  };
in
{
  hass.voice.intents = lib.mapAttrs' mkIntent areasWithClimate;
  hass.voice.intent_scripts = lib.mapAttrs' mkScript areasWithClimate;
}
