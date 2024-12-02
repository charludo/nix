{ config, ... }:
let
  e = config.hass.entities;
  pool = builtins.attrValues e.timer;

  startTimer = secsExpr: [
    {
      variables.chosen = ''
        {% set free = states.timer | selectattr('state', 'eq', 'idle') | list %}
        {{ free[0].entity_id if free else '${builtins.head pool}' }}
      '';
    }
    {
      action = "timer.start";
      target.entity_id = "{{ chosen }}";
      data.duration = ''
        {% set s = ${secsExpr} %}
        {{ '%02d:%02d:%02d' | format(s // 3600, (s % 3600) // 60, s % 60) }}
      '';
    }
    {
      action = "input_text.set_value";
      target.entity_id = ''input_text.{{ chosen | replace("timer.", "") }}_area'';
      data.value = ''{{ preferred_area_id | default("") }}'';
    }
  ];
in
{
  hass.voice.intents = {
    TimerStellenMinuten = {
      sentences = [
        "[Stelle|Starte] [einen] Timer (für|auf) {timer_minutes:minutes} Minuten"
        "{timer_minutes:minutes} Minuten an jetzt"
      ];
      script = {
        action = startTimer "(minutes | int) * 60";
        speech.text = "{{ minutes }} Minuten Timer - ab jetzt.";
      };
    };

    TimerStellenSekunden = {
      sentences = [
        "[Stelle|Starte] [einen] Timer (für|auf) {timer_seconds:seconds} Sekunden"
        "{timer_seconds:seconds} Sekunden ab jetzt"
      ];
      script = {
        action = startTimer "seconds | int";
        speech.text = "{{ seconds }} Sekunden Timer - ab jetzt.";
      };
    };

    TimerStellenStunden = {
      sentences = [
        "[Stelle|Starte] [einen] Timer (für|auf) {timer_hours:hours} Stunden"
        "{timer_hours:hours} Stunden ab jetzt"
      ];
      script = {
        action = startTimer "(hours | int) * 3600";
        speech.text = "{{ hours }} Stunden Timer - ab jetzt.";
      };
    };

    TimerStellenKombiniert = {
      sentences = [
        "[Stelle|Starte] [einen] Timer (für|auf) {timer_hours:hours} Stunden [und] {timer_minutes:minutes} Minuten"
        "{timer_hours:hours} Stunden [und] {timer_minutes:minutes} Minuten ab jetzt"
      ];
      script = {
        action = startTimer "(hours | int) * 3600 + (minutes | int) * 60";
        speech.text = "{{ hours }} Stunden und {{ minutes }} Minuten Timer - ab jetzt.";
      };
    };

    TimerAbbrechen = {
      sentences = [
        "(Brich|Stoppe) alle Timer ab"
        "Alle Timer (abbrechen|stoppen|löschen)"
      ];
      script = {
        action = [
          {
            action = "timer.cancel";
            target.entity_id = pool;
          }
        ];
        speech.text = "Alle Timer abgebrochen.";
      };
    };

    TimerRestzeit = {
      sentences = [
        "Wie lang [geht der Timer] noch"
        "Wie viel Zeit (ist|bleibt|verbleibt) ([noch] [auf dem Timer]|bis der Timer (geht|klingelt))"
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
