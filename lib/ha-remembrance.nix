{ lib }:
# Building blocks for voice intents on top of hass-remembrance (timers,
# reminders, alarms): sentence shapes, slot lists, the service call, and Jinja
# macros for the spoken answers. German only.
rec {
  # Alarms with a "Musik: <playlist>" line in their description (just
  # "Musik": this one) wake up to that playlist instead of the chime.
  defaultWakePlaylist = "500 random tracks (from library)";

  # Jinja macros, prepended to a template that uses them:
  #   dauer(seconds)  "1 Minute und 30 Sekunden"; whole minutes from 10 min
  #   timer_name(t)   "Nudel-Timer", "5 Minuten Timer",
  #                   "Timer über 1 Stunde und 30 Minuten"
  #                   (no hyphen after a number: Pocket TTS's normaliser
  #                   doesn't spell out "5-Minuten" and garbles it)
  #   und(names)      "A, B und C"
  #   timer_choices(items)  "Du hast 2 Timer: einen 5 Minuten Timer und
  #                   einen Nudel-Timer." (a satellite can't take a follow-up
  #                   answer, so ambiguity lists instead of asking)
  #   uhrzeit(dt)     "7 Uhr", "13:30 Uhr"
  #   zeitpunkt(iso)  "heute um 13 Uhr", "morgen um 7:30 Uhr",
  #                   "am Samstag um 9 Uhr", "am 3.11. um 9 Uhr"
  #   datum(iso)      "heute", "morgen", "am Samstag", "am 3.11."; a
  #                   naive one ("2026-11-15T00:00:00") is a local date
  #   wecker_choices(items)      "Du hast 2 Wecker: morgen um 7 Uhr und
  #                              am Samstag um 8:30 Uhr."
  #   erinnerung_choices(items)  "Du hast 2 Erinnerungen: an Zahnarzt und an
  #                              Blumen gießen."
  #   wake_playlist(description) the playlist an alarm wakes up to, "" if none
  #   wake_gentle(description)   "1" if the alarm gets louder gently ("Sanft"
  #                              line), "" if it rings at full volume
  # `t` is an item as remembrance's services and events return it.
  jinja = ''
    {%- macro dauer(sec) -%}
      {%- set t = sec | float(0) | round(0) | int -%}
      {%- if t >= 600 -%}{%- set t = ((t / 60) | round(0) | int) * 60 -%}{%- endif -%}
      {%- set h = t // 3600 -%}{%- set m = (t % 3600) // 60 -%}{%- set s = t % 60 -%}
      {%- set ns = namespace(p=[]) -%}
      {%- if h -%}{%- set ns.p = ns.p + [h ~ (' Stunde' if h == 1 else ' Stunden')] -%}{%- endif -%}
      {%- if m -%}{%- set ns.p = ns.p + [m ~ (' Minute' if m == 1 else ' Minuten')] -%}{%- endif -%}
      {%- if s or not ns.p -%}{%- set ns.p = ns.p + [s ~ (' Sekunde' if s == 1 else ' Sekunden')] -%}{%- endif -%}
      {{- (ns.p[:-1] | join(', ') ~ ' und ' ~ ns.p[-1]) if ns.p | length > 1 else ns.p[0] -}}
    {%- endmacro -%}
    {%- macro timer_name(t) -%}
      {%- set d = t.duration | float(0) | round(0) | int -%}
      {%- if t.label -%}{{ t.label }}-Timer
      {%- elif d == 3600 -%}Ein-Stunden-Timer
      {%- elif d == 60 -%}Ein-Minuten-Timer
      {%- elif d % 3600 == 0 -%}{{ d // 3600 }} Stunden Timer
      {%- elif d < 3600 and d % 60 == 0 -%}{{ d // 60 }} Minuten Timer
      {%- elif d < 60 -%}{{ d }} Sekunden Timer
      {%- else -%}Timer über {{ dauer(d) }}
      {%- endif -%}
    {%- endmacro -%}
    {%- macro und(names) -%}
      {{- (names[:-1] | join(', ') ~ ' und ' ~ names[-1]) if names | length > 1 else names[0] -}}
    {%- endmacro -%}
    {%- macro timer_choices(items) -%}
      {%- set ns = namespace(n=[]) -%}
      {%- for t in items -%}{%- set ns.n = ns.n + ['einen ' ~ timer_name(t)] -%}{%- endfor -%}
      Du hast {{ items | length }} Timer: {{ und(ns.n) }}.
    {%- endmacro -%}
    {%- macro uhrzeit(dt) -%}
      {{- dt.hour ~ (' Uhr' if dt.minute == 0 else ':' ~ '%02d' | format(dt.minute) ~ ' Uhr') -}}
    {%- endmacro -%}
    {%- macro datum(iso) -%}
      {%- set dt = as_datetime(iso) -%}
      {%- set d = as_local(dt).date() if dt.tzinfo else dt.date() -%}
      {%- set days = (d - now().date()).days -%}
      {%- set wochentage = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'] -%}
      {%- if days == 0 -%}heute
      {%- elif days == 1 -%}morgen
      {%- elif days == 2 -%}übermorgen
      {%- elif 2 < days < 7 -%}am {{ wochentage[d.weekday()] }}
      {%- else -%}am {{ d.day }}.{{ d.month }}.
      {%- endif -%}
    {%- endmacro -%}
    {%- macro zeitpunkt(iso) -%}
      {%- set dt = as_local(as_datetime(iso)) -%}
      {{- datum(iso) }} um {{ uhrzeit(dt) -}}
    {%- endmacro -%}
    {%- macro wecker_choices(items) -%}
      {%- set ns = namespace(n=[]) -%}
      {%- for i in items -%}{%- set ns.n = ns.n + [zeitpunkt(i.next_ring or i.start)] -%}{%- endfor -%}
      Du hast {{ items | length }} Wecker: {{ und(ns.n) }}.
    {%- endmacro -%}
    {%- macro erinnerung_choices(items) -%}
      Du hast {{ items | length }} Erinnerungen: {{ und(items | map(attribute='label') | map('regex_replace', '^', 'an ') | list) }}.
    {%- endmacro -%}
    {%- macro wake_playlist(description) -%}
      {%- set m = (description or "") | regex_findall('(?im)^\s*musik\s*:?\s*(.*?)\s*$') -%}
      {{- (m[0] or "${defaultWakePlaylist}") if m else "" -}}
    {%- endmacro -%}
    {%- macro wake_gentle(description) -%}
      {{- "1" if (description or "") | regex_search('(?im)^\s*sanft\s*$') else "" -}}
    {%- endmacro -%}
  '';

  area = "{{ preferred_area_id | default('') }}";

  # Answers to a failed calendar write, as Jinja `elif` branches on `res`;
  # `what` names the items ("Erinnerungen", "Wecker").
  failed = what: ''
    {%- elif res.reason == 'no calendar configured' -%}${what} sind noch nicht eingerichtet.
    {%- elif res.reason == 'in the past' -%}Dieser Zeitpunkt ist schon vorbei.
    {%- elif (res.reason or "").startswith('calendar') -%}Ich komme gerade nicht an den Kalender.
  '';

  # Answers to a sentence `create_from_text` didn't understand, as Jinja
  # `elif` branches on `res` (more per kind: `no duration`, `no summary`).
  notUnderstood = ''
    {%- elif res.reason == 'vague time' -%}Bitte sag mir eine genaue Uhrzeit.
    {%- elif res.reason == 'no time' -%}Ich habe keine Uhrzeit verstanden.
    {%- elif (res.reason or "").startswith('duckling') or res.reason == 'no duckling configured' -%}Ich kann gerade keine Zeitangaben lesen.
  '';

  # Call `remembrance.<service>` and stop with its response, which the
  # speech reads as `action_response`.
  callService = service: data: [
    {
      action = "remembrance.${service}";
      inherit data;
      response_variable = "r";
    }
    {
      stop = "";
      response_variable = "r";
    }
  ];
}
