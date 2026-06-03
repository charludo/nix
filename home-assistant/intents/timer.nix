{ config, ... }:
let
  e = config.hass.entities;
  pool = builtins.attrValues e.timer;

  # Jinja: pick the first idle timer from the pool, fall back to first.
  pickIdle = ''
    {% set free = states.timer | selectattr('state', 'eq', 'idle') | list %}
    {{ free[0].entity_id if free else '${builtins.head pool}' }}
  '';

  # HH:MM:SS from total seconds, handling overflows past 59 minutes.
  fmtDuration = secsExpr: ''
    {% set s = ${secsExpr} %}
    {{ '%02d:%02d:%02d' | format(s // 3600, (s % 3600) // 60, s % 60) }}
  '';

  startTimer = secsExpr: [
    {
      action = "timer.start";
      target.entity_id = pickIdle;
      data.duration = fmtDuration secsExpr;
    }
  ];
in
{
  hass.voice.intents = {
    TimerStellenMinuten = {
      sentences = [
        "(Stelle|Setze|Starte) [einen] Timer (für|auf) {timer_minutes:minutes} Minuten"
        "Timer (für|auf) {timer_minutes:minutes} Minuten"
        "Timer {timer_minutes:minutes} Minuten"
      ];
      script = {
        action = startTimer "(minutes | int) * 60";
        speech.text = "Timer für {{ minutes }} Minuten gestartet.";
      };
    };

    TimerStellenSekunden = {
      sentences = [
        "(Stelle|Setze|Starte) [einen] Timer (für|auf) {timer_seconds:seconds} Sekunden"
        "Timer {timer_seconds:seconds} Sekunden"
      ];
      script = {
        action = startTimer "seconds | int";
        speech.text = "Timer für {{ seconds }} Sekunden gestartet.";
      };
    };

    TimerStellenStunden = {
      sentences = [
        "(Stelle|Setze|Starte) [einen] Timer (für|auf) {timer_hours:hours} Stunden"
        "Timer {timer_hours:hours} Stunden"
      ];
      script = {
        action = startTimer "(hours | int) * 3600";
        speech.text = "Timer für {{ hours }} Stunden gestartet.";
      };
    };

    TimerStellenKombiniert = {
      sentences = [
        "(Stelle|Setze|Starte) [einen] Timer (für|auf) {timer_hours:hours} Stunden [und] {timer_minutes:minutes} Minuten"
      ];
      script = {
        action = startTimer "(hours | int) * 3600 + (minutes | int) * 60";
        speech.text = "Timer für {{ hours }} Stunden und {{ minutes }} Minuten gestartet.";
      };
    };

    TimerAbbrechen = {
      sentences = [
        "(Brich|Stoppe) [den|alle] Timer ab"
        "Timer (abbrechen|stoppen|löschen)"
        "alle Timer (abbrechen|stoppen)"
      ];
      script = {
        action = [
          {
            action = "timer.cancel";
            target.entity_id = pool;
          }
        ];
        speech.text = "Timer abgebrochen.";
      };
    };

    TimerRestzeit = {
      sentences = [
        "Wie viel Zeit (ist|bleibt) [noch] [auf dem Timer]"
        "(Wann|Wie lange noch) [bis der] Timer (klingelt|fertig)"
        "Timer (Status|Restzeit)"
      ];
      script.speech.text = ''
        {% set active = states.timer | selectattr('state', 'eq', 'active') | list %}
        {% if active | length == 0 %}
          Es läuft kein Timer.
        {% else %}
          {% for t in active %}
            {% set rem = (as_timestamp(t.attributes.finishes_at) - as_timestamp(now())) | int %}
            {% set m = rem // 60 %}
            {% set s = rem % 60 %}
            {{ t.attributes.friendly_name }}: noch {{ m }} Minuten {{ s }} Sekunden.
          {% endfor %}
        {% endif %}
      '';
    };
  };
}
