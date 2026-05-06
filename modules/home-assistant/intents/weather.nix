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
      "Wie [wird|ist] das Wetter um {timer_hours:hours} Uhr"
      "Wie warm wird es um {timer_hours:hours} Uhr"
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
      "Regnet es [heute|heute noch]"
      "Wird es heute regnen"
      "Gibt es heute Regen"
    ];
    RegenStunde = [
      "Regnet es um {timer_hours:hours} Uhr"
      "Wird es um {timer_hours:hours} Uhr regnen"
      "Gibt es um {timer_hours:hours} Uhr Regen"
    ];
  };

  hass.voice.intent_scripts = {
    WetterHeute.speech.text = ''
      Aktuell sind es draußen {{ (states('${s.openweathermap_temperatur}') | float | round(1) | string).replace('.', ',') }} Grad, gefühlt {{ states('${s.openweathermap_gefuhlte_temperatur}') | float | round(0) | int }} Grad.
    '';

    WetterMorgen.speech.text = ''
      {% set f = state_attr('${w}', 'forecast')[1] %}
      Morgen werden es {{ (f.temperature | float | round(1) | string).replace('.', ',') }} Grad mit einer Tiefsttemperatur von {{ (f.templow | float | round(1) | string).replace('.', ',') }} Grad. Niederschlag: {{ (f.precipitation | float | round(1) | string).replace('.', ',') }} Millimeter.
    '';

    WetterWoche.speech.text = ''
      {% set f = state_attr('${w}', 'forecast') %}
      {% for d in f[:7] -%}
        {{ as_timestamp(d.datetime) | timestamp_custom('%A') }}: {{ (f.templow | float | round(1) | string).replace('.', ',') }} bis {{ (f.temperature | float | round(1) | string).replace('.', ',') }} Grad..
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
          Um {{ h }} Uhr werden es {{ (m.temperature | float | round(1) | string).replace('.', ',') }} Grad bei {{ m.condition }}, Niederschlag {{ m.precipitation | default(0) }} Millimeter mit {{ m.precipitation_probability | default(0) }} Prozent Wahrscheinlichkeit.
        {% else %}
          Für {{ h }} Uhr habe ich keine Vorhersage.
        {% endif %}
      '';
    };

    WindAktuell.speech.text = ''
      Aktuell weht der Wind mit {{ (states('${s.openweathermap_windgeschwindigkeit}') | float | round(1) | string).replace('.', ',') }} Kilometer pro Stunde, bei Böen bis {{ (states('${s.openweathermap_windboengeschwindigkeit}') | float | round(1) | string).replace('.', ',') }}.
    '';

    WindHeuteNacht.speech.text = ''
      {% set f = state_attr('${w}', 'forecast')[0] %}
      Heute Nacht etwa {{ (f.wind_speed | default(0) | float | round(0) | string).replace('.', ',') }} Kilometer pro Stunde.
    '';

    TemperaturMaxHeute.speech.text = ''
      {% set f = state_attr('${w}', 'forecast')[0] %}
      Heute werden es bis zu {{ (f.temperature | float | round(1) | string).replace('.', ',') }} Grad bei einer Tiefsttemperatur von {{ (f.templow | float | round(1) | string).replace('.', ',') }}.
    '';

    RegenHeute.speech.text = ''
      {% set f = state_attr('${w}', 'forecast')[0] %}
      {% set p = (f.precipitation | default(0) | float | round(0) | string).replace('.', ',') %}
      {% set prob = (f.precipitation_probability | default(0) | float | round(0) | string).replace('.', ',') %}
      {% if p > 0 or prob > 30 %}
        Heute sind {{ p }} Millimeter Regen mit einer Wahrscheinlichkeit von {{ prob }} Prozent erwartet.
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
          {% set p = (m.precipitation | default(0) | float | round(0) | string).replace('.', ',') %}
          {% set prob = (m.precipitation_probability | default(0) | float | round(0) | string).replace('.', ',') %}
          Um {{ h }} Uhr: {{ p }} Millimeter Regen mit {{ prob }} Prozent Wahrscheinlichkeit.
        {% else %}
          Für {{ h }} Uhr habe ich keine Regenvorhersage.
        {% endif %}
      '';
    };
  };
}
