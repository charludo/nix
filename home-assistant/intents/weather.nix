{ config, ... }:
let
  e = config.hass.entities;
  s = e.sensor;
  w = e.weather.openweathermap;
  daily = s.openweathermap_forecast_daily;
  hourly = s.openweathermap_forecast_hourly;
  local = s.wetterstation;

  num = expr: "{{ (${expr} | float(0) | round(1) | string).replace('.', ',') }}";
  pct = expr: "{{ ${expr} | float(0) | round(0) | int }}";

  cond =
    expr:
    "{{ {'sunny':'sonnig','clear-night':'klar','cloudy':'bewölkt','partlycloudy':'teilweise bewölkt','rainy':'regnerisch','pouring':'stark regnerisch','lightning':'gewittrig','lightning-rainy':'gewittrig mit Regen','snowy':'schneit','snowy-rainy':'Schneeregen','fog':'neblig','hail':'Hagel','windy':'windig','windy-variant':'windig','exceptional':'außergewöhnlich'}.get(${expr}, ${expr}) }}";

  weekday =
    expr:
    "{{ ['Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag','Sonntag'][as_datetime(${expr}).weekday()] }}";

  withDailyForecast =
    i: body:
    ''
      {% set f = state_attr('${daily}', 'forecast')[${toString i}] %}
    ''
    + body;

  findHourly = ''
    {% set h = hours | int %}
    {% set ns = namespace(m=none) %}
    {% for e in state_attr('${hourly}', 'forecast') %}
      {% if ns.m is none and as_local(as_datetime(e.datetime)).hour == h %}
        {% set ns.m = e %}
      {% endif %}
    {% endfor %}
    {% set m = ns.m %}
  '';

  hourIntent = sentences: body: {
    inherit sentences;
    lists.hours.range = {
      from = 0;
      to = 23;
    };
    script.speech.text = findHourly + body;
  };

  sunSpeech =
    {
      attr,
      day,
      particle,
      past ? null,
    }:
    let
      t = "as_local(as_datetime(state_attr('${e.sun.sun}', '${attr}')))";
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
        {% set shifted = t if t.date() != now().date() else t + timedelta(days=1) %}
        Die Sonne geht morgen um {{ shifted.strftime('%H:%M') }} Uhr ${particle}.
      '';
in
{
  hass.voice.intents = {
    WetterHeute = {
      sentences = [
        "Wie (ist das Wetter|warm ist es) [heute|draußen|gerade|jetzt|aktuell]"
      ];
      script.speech.text = ''
        Aktuell ist es ${cond "states('${w}')"} bei ${num "states('${local.temperature}')"} Grad, gefühlt ${num "states('${s.openweathermap_gefuhlte_temperatur}')"} Grad.
      '';
    };

    WetterMorgen = {
      sentences = [
        "Wie ((wird|ist) das Wetter|warm wird es) morgen"
      ];
      script.speech.text = withDailyForecast 1 ''
        Morgen wird es ${cond "f.condition"} mit ${num "f.temperature"} Grad und einer Tiefsttemperatur von ${num "f.templow"} Grad. Niederschlag: ${num "f.precipitation"} Millimeter.
      '';
    };

    WetterWoche = {
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

    WetterStunde =
      hourIntent
        [
          "Wie ((wird|ist) das Wetter|warm (wird|ist) es) um {hours} Uhr"
        ]
        ''
          {% if m %}
            Um {{ h }} Uhr wird es ${cond "m.condition"} bei ${num "m.temperature"} Grad, Niederschlag ${num "m.precipitation | default(0)"} Millimeter mit ${pct "m.precipitation_probability | default(0)"} Prozent Wahrscheinlichkeit.
          {% else %}
            Für {{ h }} Uhr habe ich keine Vorhersage.
          {% endif %}
        '';

    WetterWindAktuell = {
      sentences = [
        "Wie windig ist es [heute|draußen|gerade|jetzt|aktuell]"
      ];
      script.speech.text = ''
        Aktuell weht der Wind mit ${num "states('${local.wind_speed}')"} Kilometern pro Stunde, bei Böen bis ${num "states('${local.gust_speed}')"} km/h.
      '';
    };

    WetterWindHeuteNacht = {
      sentences = [
        "Wie windig (wird|ist) es (heute Nacht|nachts|heute Abend)"
      ];
      script.speech.text = withDailyForecast 0 ''
        Heute Nacht weht der Wind mit etwa ${num "f.wind_speed | default(0)"} Kilometern pro Stunde.
      '';
    };

    WetterTemperaturMaxHeute = {
      sentences = [
        "Wie (wird das Wetter|(warm|kalt) wird es) heute [noch]"
        "Was ist die (Höchsttemperatur|Tiefsttemperatur) heute"
      ];
      script.speech.text = withDailyForecast 0 ''
        Heute werden es bis zu ${num "f.temperature"} Grad bei einer Tiefsttemperatur von ${num "f.templow"} Grad.
      '';
    };

    WetterRegenHeute = {
      sentences = [
        "(Wird|Gibt) es heute [noch] (regnen|Regen)"
        "Regnet es heute [noch]"
      ];
      script.speech.text = withDailyForecast 0 ''
        {% set p = f.precipitation | default(0) | float(0) %}
        {% set prob = f.precipitation_probability | default(0) | float(0) %}
        {% if p > 0 or prob > 30 %}
          Heute sind ${num "p"} Millimeter Regen mit einer Wahrscheinlichkeit von ${pct "prob"} Prozent erwartet.
        {% else %}
          Heute regnet es voraussichtlich nicht.
        {% endif %}
      '';
    };

    WetterRegenStunde =
      hourIntent
        [
          "(Wird|Gibt) es [heute] um {hours} Uhr (regnen|Regen)"
          "Regnet es [heute] um {hours} Uhr"
        ]
        ''
          {% if m %}
            Um {{ h }} Uhr: ${num "m.precipitation | default(0)"} Millimeter Regen mit ${pct "m.precipitation_probability | default(0)"} Prozent Wahrscheinlichkeit.
          {% else %}
            Für {{ h }} Uhr habe ich keine Regenvorhersage.
          {% endif %}
        '';

    SonnenaufgangHeute = {
      sentences = [
        "Wann (ist|geht) die Sonne [heute] auf[gegangen]"
        "Wann ist heute [der|früh] Sonnenaufgang [gewesen]"
      ];
      script.speech.text = sunSpeech {
        attr = "next_rising";
        day = "heute";
        particle = "auf";
        past = "aufgegangen";
      };
    };

    SonnenaufgangMorgen = {
      sentences = [
        "Wann geht die Sonne morgen auf"
        "Wann ist morgen [der|früh] Sonnenaufgang"
      ];
      script.speech.text = sunSpeech {
        attr = "next_rising";
        day = "morgen";
        particle = "auf";
      };
    };

    SonnenuntergangHeute = {
      sentences = [
        "Wann (ist|geht) die Sonne [heute] unter[gegangen]"
        "Wann ist heute [der|Abend] Sonnenuntergang [gewesen]"
      ];
      script.speech.text = sunSpeech {
        attr = "next_setting";
        day = "heute";
        particle = "unter";
        past = "untergegangen";
      };
    };

    SonnenuntergangMorgen = {
      sentences = [
        "Wann geht die Sonne morgen unter"
        "Wann ist morgen [der|Abend] Sonnenuntergang"
      ];
      script.speech.text = sunSpeech {
        attr = "next_setting";
        day = "morgen";
        particle = "unter";
      };
    };
  };
}
