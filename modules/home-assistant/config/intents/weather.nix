{ config, ... }:
let
  e = config.hass.entities;
  s = e.sensor;
  w = e.weather.openweathermap;
  daily = s.openweathermap_forecast_daily;
  hourly = s.openweathermap_forecast_hourly;
  # Local Wetterstation (Sonoff, Terrasse) — preferred for "current" queries.
  local = s.wetterstation;

  # `num e` formats `e` to one decimal with German comma; `pct e` rounds to a whole percent.
  num = expr: "{{ (${expr} | float(0) | round(1) | string).replace('.', ',') }}";
  pct = expr: "{{ ${expr} | float(0) | round(0) | int }}";

  # Translate an HA weather `condition` string into German.
  cond =
    expr:
    "{{ {'sunny':'sonnig','clear-night':'klar','cloudy':'bewölkt','partlycloudy':'teilweise bewölkt','rainy':'regnerisch','pouring':'stark regnerisch','lightning':'gewittrig','lightning-rainy':'gewittrig mit Regen','snowy':'schneit','snowy-rainy':'Schneeregen','fog':'neblig','hail':'Hagel','windy':'windig','windy-variant':'windig','exceptional':'außergewöhnlich'}.get(${expr}, ${expr}) }}";

  # German weekday name from an ISO datetime string.
  weekday =
    expr:
    "{{ ['Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag','Sonntag'][as_datetime(${expr}).weekday()] }}";

  hoursList.lists.hours.range = {
    from = 0;
    to = 23;
  };

  # Speech for "{Sonnenaufgang,Sonnenuntergang} {heute,morgen}". `attr` selects the
  # sun.sun attribute (next_rising/next_setting), `particle` is the German verb
  # particle (auf/unter), `past` the participle (aufgegangen/untergegangen).
  # We use `next_*` from sun.sun and a ±1-day shift to derive today/tomorrow when
  # the next event is on the other day.
  sunSpeech =
    {
      attr,
      day,
      particle,
      past,
    }:
    let
      t = "as_datetime(state_attr('${e.sun.sun}', '${attr}'))";
    in
    if day == "heute" then
      ''
        {% set t = ${t} %}
        {% if t.date() == now().date() %}
          Die Sonne geht heute um {{ t.strftime('%H:%M') }} Uhr ${particle}.
        {% else %}
          Die Sonne ist heute um {{ (t - timedelta(days=1)).strftime('%H:%M') }} Uhr ${past}.
        {% endif %}
      ''
    else
      ''
        {% set t = ${t} %}
        {% if t.date() == now().date() %}
          Die Sonne geht morgen um {{ (t + timedelta(days=1)).strftime('%H:%M') }} Uhr ${particle}.
        {% else %}
          Die Sonne geht morgen um {{ t.strftime('%H:%M') }} Uhr ${particle}.
        {% endif %}
      '';
in
{
  hass.voice = {
    Wetter_Heute = {
      sentences = [
        "Wie ist das Wetter (gerade|draußen|aktuell)"
        "Wie warm ist es (draußen|gerade|jetzt)"
      ];
      # Temperature, humidity, pressure straight from the local Wetterstation;
      # condition string comes from OWM (categorical, not measured locally),
      # gefühlte Temperatur stays OWM-derived.
      script.speech.text = ''
        Aktuell ist es ${cond "states('${w}')"} bei ${num "states('${local.temperature}')"} Grad, gefühlt ${num "states('${s.openweathermap_gefuhlte_temperatur}')"} Grad.
      '';
    };

    Wetter_Morgen = {
      sentences = [
        "Wie wird das Wetter morgen [früh|nachmittag|abend]"
        "Wie warm wird es morgen"
      ];
      script.speech.text = ''
        {% set f = state_attr('${daily}', 'forecast')[1] %}
        Morgen wird es ${cond "f.condition"} mit ${num "f.temperature"} Grad und einer Tiefsttemperatur von ${num "f.templow"} Grad. Niederschlag: ${num "f.precipitation"} Millimeter.
      '';
    };

    Wetter_Woche = {
      sentences = [
        "Wie wird das Wetter (diese Woche|in den nächsten Tagen|die nächste Woche)"
        "Wettervorhersage [für die nächsten Tage]"
      ];
      script.speech.text = ''
        {% for d in state_attr('${daily}', 'forecast')[1:8] -%}
          ${weekday "d.datetime"}: ${cond "d.condition"}, ${num "d.templow"} bis ${num "d.temperature"} Grad.
        {% endfor %}
      '';
    };

    Wetter_Stunde = hoursList // {
      sentences = [
        "Wie [wird|ist] das Wetter um {hours} Uhr"
        "Wie warm wird es um {hours} Uhr"
      ];
      script.speech.text = ''
        {% set h = hours | int %}
        {% set entries = state_attr('${hourly}', 'forecast') %}
        {% set match = entries | selectattr('datetime', 'match', '.*T' ~ '%02d' | format(h) ~ ':') | list %}
        {% if match %}
          {% set m = match[0] %}
          Um {{ h }} Uhr wird es ${cond "m.condition"} bei ${num "m.temperature"} Grad, Niederschlag ${num "m.precipitation | default(0)"} Millimeter mit ${pct "m.precipitation_probability | default(0)"} Prozent Wahrscheinlichkeit.
        {% else %}
          Für {{ h }} Uhr habe ich keine Vorhersage.
        {% endif %}
      '';
    };

    Wetter_WindAktuell = {
      sentences = [
        "Wie windig ist es [heute|jetzt|gerade]"
        "Wie stark weht der Wind"
      ];
      script.speech.text = ''
        Aktuell weht der Wind mit ${num "states('${local.wind_speed}')"} Kilometern pro Stunde, bei Böen bis ${num "states('${local.wind_gust}')"} km/h.
      '';
    };

    Wetter_WindHeuteNacht = {
      sentences = [
        "Wie windig wird es (heute Nacht|nachts|heute Abend)"
      ];
      script.speech.text = ''
        {% set f = state_attr('${daily}', 'forecast')[0] %}
        Heute Nacht weht der Wind mit etwa ${num "f.wind_speed | default(0)"} Kilometern pro Stunde.
      '';
    };

    Wetter_TemperaturMaxHeute = {
      sentences = [
        "Wie warm wird es heute [noch]"
        "Was ist die Höchsttemperatur heute"
      ];
      script.speech.text = ''
        {% set f = state_attr('${daily}', 'forecast')[0] %}
        Heute werden es bis zu ${num "f.temperature"} Grad bei einer Tiefsttemperatur von ${num "f.templow"} Grad.
      '';
    };

    Wetter_RegenHeute = {
      sentences = [
        "Regnet es [heute|heute noch]"
        "Wird es heute regnen"
        "Gibt es heute Regen"
      ];
      script.speech.text = ''
        {% set f = state_attr('${daily}', 'forecast')[0] %}
        {% set p = f.precipitation | default(0) | float(0) %}
        {% set prob = f.precipitation_probability | default(0) | float(0) %}
        {% if p > 0 or prob > 30 %}
          Heute sind ${num "p"} Millimeter Regen mit einer Wahrscheinlichkeit von ${pct "prob"} Prozent erwartet.
        {% else %}
          Heute regnet es voraussichtlich nicht.
        {% endif %}
      '';
    };

    Wetter_RegenStunde = hoursList // {
      sentences = [
        "Regnet es um {hours} Uhr"
        "Wird es um {hours} Uhr regnen"
        "Gibt es um {hours} Uhr Regen"
      ];
      script.speech.text = ''
        {% set h = hours | int %}
        {% set entries = state_attr('${hourly}', 'forecast') %}
        {% set match = entries | selectattr('datetime', 'match', '.*T' ~ '%02d' | format(h) ~ ':') | list %}
        {% if match %}
          {% set m = match[0] %}
          Um {{ h }} Uhr: ${num "m.precipitation | default(0)"} Millimeter Regen mit ${pct "m.precipitation_probability | default(0)"} Prozent Wahrscheinlichkeit.
        {% else %}
          Für {{ h }} Uhr habe ich keine Regenvorhersage.
        {% endif %}
      '';
    };

    Sonnenaufgang_Heute = {
      sentences = [
        "Wann geht die Sonne [heute] auf"
        "Wann ist [heute] [der ]Sonnenaufgang"
      ];
      script.speech.text = sunSpeech {
        attr = "next_rising";
        day = "heute";
        particle = "auf";
        past = "aufgegangen";
      };
    };

    Sonnenaufgang_Morgen = {
      sentences = [
        "Wann geht die Sonne morgen auf"
        "Wann ist morgen [der ]Sonnenaufgang"
      ];
      script.speech.text = sunSpeech {
        attr = "next_rising";
        day = "morgen";
        particle = "auf";
        past = "aufgegangen";
      };
    };

    Sonnenuntergang_Heute = {
      sentences = [
        "Wann geht die Sonne [heute] unter"
        "Wann ist [heute] [der ]Sonnenuntergang"
      ];
      script.speech.text = sunSpeech {
        attr = "next_setting";
        day = "heute";
        particle = "unter";
        past = "untergegangen";
      };
    };

    Sonnenuntergang_Morgen = {
      sentences = [
        "Wann geht die Sonne morgen unter"
        "Wann ist morgen [der ]Sonnenuntergang"
      ];
      script.speech.text = sunSpeech {
        attr = "next_setting";
        day = "morgen";
        particle = "unter";
        past = "untergegangen";
      };
    };
  };
}
