{ lib, config, ... }:
let
  e = config.hass.entities;
  w = e.weather.openweathermap;
  s = e.sensor;
in
{
  hass.voice.intents = {
    WetterHeute = [
      "Wie ist das Wetter (heute|jetzt|gerade|draußen|aktuell)"
      "Wie warm ist es (draußen|gerade|jetzt)"
    ];
    WetterMorgen = [
      "Wie wird das Wetter morgen [früh|nachmittag|abend]"
      "Wie warm wird es morgen"
    ];
    WetterWoche = [
      "Wie wird das Wetter (diese Woche|in den nächsten Tagen|die nächste Woche)"
      "Wettervorhersage [für die nächsten Tage]"
    ];
    WetterStunde = [
      "Wie [wird|ist] das Wetter um {stunde} Uhr"
      "Wie warm wird es um {stunde} Uhr"
    ];
    WindAktuell = [
      "Wie windig ist es [heute|jetzt|gerade]"
      "Wie stark weht der Wind"
    ];
    WindHeuteNacht = [
      "Wie windig wird es (heute Nacht|nachts|heute Abend)"
    ];
    TemperaturMaxHeute = [
      "Wie warm wird es heute [noch]"
      "Was ist die Höchsttemperatur heute"
    ];
    RegenHeute = [
      "Regnet es [heute|noch heute]"
      "Wird es heute regnen"
    ];
    RegenStunde = [
      "Regnet es um {stunde} Uhr"
      "Wird es um {stunde} Uhr regnen"
    ];
  };

  hass.voice.intent_scripts = {
    WetterHeute.speech.text = ''
      Aktuell sind es {{ states('${s.openweathermap_temperatur}') | round(0) }} Grad draußen, gefühlt {{ states('${s.openweathermap_gefuhlte_temperatur}') | round(0) }}.
    '';

    WetterMorgen.speech.text = ''
      {% set f = state_attr('${w}', 'forecast')[1] %}
      Morgen werden es {{ f.temperature | round(0) }} Grad mit einer Tiefsttemperatur von {{ f.templow | round(0) }} Grad. Niederschlag: {{ f.precipitation | default(0) }} Millimeter.
    '';

    WetterWoche.speech.text = ''
      {% set f = state_attr('${w}', 'forecast') %}
      {% for d in f[:7] -%}
        {{ as_timestamp(d.datetime) | timestamp_custom('%A') }}: {{ d.temperature | round(0) }} Grad, Tief {{ d.templow | round(0) }}.
      {% endfor %}
    '';

    WetterStunde = {
      action = [
        {
          action = "weather.get_forecasts";
          target.entity_id = w;
          data.type = "hourly";
          response_variable = "forecast";
        }
      ];
      speech.text = ''
        {% set h = stunde | int %}
        {% set entries = forecast['${w}'].forecast %}
        {% set match = entries | selectattr('datetime', 'match', '.*T' ~ '%02d' | format(h) ~ ':') | list %}
        {% if match %}
          {% set m = match[0] %}
          Um {{ h }} Uhr werden es {{ m.temperature | round(0) }} Grad bei {{ m.condition }}, Niederschlag {{ m.precipitation | default(0) }} Millimeter mit {{ m.precipitation_probability | default(0) }} Prozent Wahrscheinlichkeit.
        {% else %}
          Für {{ h }} Uhr habe ich keine Vorhersage.
        {% endif %}
      '';
    };

    WindAktuell.speech.text = ''
      Aktuell weht der Wind mit {{ states('${s.openweathermap_windgeschwindigkeit}') }} Kilometer pro Stunde, mit Böen bis {{ states('${s.openweathermap_windboengeschwindigkeit}') }}.
    '';

    WindHeuteNacht.speech.text = ''
      {% set f = state_attr('${w}', 'forecast')[0] %}
      Heute Nacht etwa {{ f.wind_speed | default(0) | round(0) }} Kilometer pro Stunde.
    '';

    TemperaturMaxHeute.speech.text = ''
      {% set f = state_attr('${w}', 'forecast')[0] %}
      Heute werden es bis zu {{ f.temperature | round(0) }} Grad bei einer Tiefsttemperatur von {{ f.templow | round(0) }}.
    '';

    RegenHeute.speech.text = ''
      {% set f = state_attr('${w}', 'forecast')[0] %}
      {% set p = f.precipitation | default(0) %}
      {% set prob = f.precipitation_probability | default(0) %}
      {% if p > 0 or prob > 30 %}
        Heute sind {{ p }} Millimeter Regen mit {{ prob }} Prozent Wahrscheinlichkeit erwartet.
      {% else %}
        Heute regnet es voraussichtlich nicht.
      {% endif %}
    '';

    RegenStunde = {
      action = [
        {
          action = "weather.get_forecasts";
          target.entity_id = w;
          data.type = "hourly";
          response_variable = "forecast";
        }
      ];
      speech.text = ''
        {% set h = stunde | int %}
        {% set entries = forecast['${w}'].forecast %}
        {% set match = entries | selectattr('datetime', 'match', '.*T' ~ '%02d' | format(h) ~ ':') | list %}
        {% if match %}
          {% set m = match[0] %}
          {% set p = m.precipitation | default(0) %}
          {% set prob = m.precipitation_probability | default(0) %}
          Um {{ h }} Uhr: {{ p }} Millimeter Regen mit {{ prob }} Prozent Wahrscheinlichkeit.
        {% else %}
          Für {{ h }} Uhr habe ich keine Regenvorhersage.
        {% endif %}
      '';
    };
  };
}
