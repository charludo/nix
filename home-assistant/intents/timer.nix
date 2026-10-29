{ lib, ... }:
let
  r = lib.ha.remembrance;
  inherit (r) area callService secondsOf;

  # "den Timer", "den 5-Minuten-Timer" (speech-to-text hyphens arrive as
  # spaces in closest_intent), "den Nudel-Timer". The label is its own
  # sentence, so the wildcard doesn't compete with a duration in one pattern.
  # Timers are named by minutes only; hours and seconds are rare enough.
  timerShapes = [
    "Timer"
    "{timer_zahl:set_minutes} Minuten Timer"
    "{timer_label:label} Timer"
  ];

  expand = r.expand {
    # Changes in one unit only: "um eine Minute", "um 30 Sekunden".
    "<aenderung>" = lib.take 3 (r.durationShapes "delta_");
    "<timer>" = timerShapes;
  };

  lists = {
    inherit (r.lists) timer_zahl;
    timer_label.wildcard = true;
  };

  # What was said about the timer, and where (only breaks ties). Unsaid
  # fields render empty or 0, which remembrance treats as not given.
  target = {
    label = "{{ label | default('') }}";
    duration = "{{ ${secondsOf "set_"} }}";
    inherit area;
  };

  # Speech for a timer action: `ok` (Jinja; `t` is the timer) on success,
  # the shared answers otherwise.
  speak = ok: ''
    ${r.jinja}
    {%- set r = action_response -%}
    {%- set t = r['items'][0] if r['items'] else none -%}
    {%- if r.status == 'ok' -%}${ok}
    {%- elif r.status == 'ambiguous' -%}Welchen meinst du? {{ timer_choices(r.candidates) }}?
    {%- elif r.status == 'no_match' -%}Diesen Timer gibt es nicht.
    {%- else -%}Das geht bei {{ 'dem ' ~ timer_name(t) if t else 'diesem Timer' }} gerade nicht.
    {%- endif -%}
  '';

  mkIntent = sentences: service: data: ok: {
    sentences = expand sentences;
    inherit lists;
    script = {
      action = callService service data;
      speech.text = speak ok;
    };
  };

  # "<timer> um 1 Minute verlängern" / "verkürzen"; `sign` 1 or -1.
  adjust =
    verb: imperative: participle: extra: sign:
    mkIntent
      (
        [
          "<timer> um <aenderung> ${verb}"
          "${imperative} den <timer> um <aenderung>"
        ]
        ++ extra
      )
      "timer_adjust"
      (target // { delta = "{{ ${toString sign} * ${secondsOf "delta_"} }}"; })
      "{{ timer_name(t) }} um {{ dauer(${secondsOf "delta_"}) }} ${participle}, noch {{ dauer(t.remaining) }}.";

  # Started from the sentence as said: remembrance reads the duration
  # ("anderthalb Stunden", "3,5 Minuten") and the label ("Nudeltimer",
  # "Nudel Timer", "Timer für die Nudeln").
  startIntents = r.fromText {
    name = "TimerStellen";
    kind = "timer";
    sentences = [
      "Stelle einen {remembrance_text:text}"
      "Starte einen {remembrance_text:text}"
      "Timer {remembrance_text:text}"
      # closest_intent drops what comes before a pattern: "Nudel Timer auf …"
      # needs its own.
      "{remembrance_text:label} Timer auf {remembrance_text:text}"
      "{remembrance_text:text} ab jetzt"
    ];
    speech = ''
      ${r.jinja}
      {%- set res = action_response -%}
      {%- set t = res['items'][0] if res['items'] else none -%}
      {%- if res.status == 'ok' -%}
        {{ timer_name(t) }}{{ ' auf ' ~ dauer(t.duration) if t.label else "" }} - ab jetzt.
      {%- elif res.reason == 'no duration' -%}Ich habe nicht verstanden, wie lange der Timer laufen soll.
      ${r.notUnderstood}
      {%- else -%}Das hat nicht geklappt.
      {%- endif -%}
    '';
  };
in
{
  hass.voice.intents = startIntents // {
    TimerVerlaengern = adjust "verlängern" "Verlängere" "verlängert" [
      "<aenderung> (hinzufügen|dazu|drauf)"
      "Füge <aenderung> hinzu"
      "Füge dem <timer> <aenderung> hinzu"
    ] 1;
    TimerVerkuerzen = adjust "verkürzen" "Verkürze" "verkürzt" [
      "<aenderung> abziehen"
      "Ziehe <aenderung> ab"
      "Ziehe vom <timer> <aenderung> ab"
    ] (-1);

    TimerPausieren = mkIntent [
      "Pausiere den <timer>"
      "Halte den <timer> an"
      "<timer> (pausieren|anhalten)"
    ] "timer_pause" target "{{ timer_name(t) }} pausiert, noch {{ dauer(t.remaining) }}.";

    TimerFortsetzen = mkIntent [
      "Setze den <timer> fort"
      "Lass den <timer> weiterlaufen"
      "<timer> (fortsetzen|weiterlaufen lassen)"
    ] "timer_resume" target "{{ timer_name(t) }} läuft weiter, noch {{ dauer(t.remaining) }}.";

    TimerLoeschen = mkIntent [
      "(Lösche|Stoppe|Beende) den <timer>"
      "Brich den <timer> ab"
      "<timer> (löschen|abbrechen|stoppen|beenden)"
    ] "timer_cancel" target "{{ timer_name(t) }} gelöscht.";

    TimerAlleLoeschen = {
      sentences = [
        "(Brich|Stoppe) alle Timer ab"
        "Alle Timer (abbrechen|stoppen|löschen)"
        "Lösche alle Timer"
      ];
      script = {
        action = callService "timer_cancel" { all = true; };
        speech.text = ''
          {%- set n = action_response['items'] | length -%}
          {{ 'Es läuft kein Timer.' if n == 0 else ('Timer gelöscht.' if n == 1 else 'Alle ' ~ n ~ ' Timer gelöscht.') }}
        '';
      };
    };

    TimerRestzeit = {
      sentences = expand [
        "Wie lange läuft der <timer> noch"
        "Wie lange noch"
        "Wie viel Zeit (ist|bleibt|verbleibt) [noch] [auf dem Timer]"
        "Wie viel Zeit (ist|bleibt|verbleibt) bis der Timer (geht|klingelt)"
      ];
      inherit lists;
      script = {
        # Narrowed down only by what was said; otherwise all timers.
        action = callService "query" {
          kind = "timer";
          inherit (target) label duration;
        };
        speech.text = ''
          ${r.jinja}
          {%- set items = action_response['items'] | rejectattr('state', 'eq', 'ringing') | list -%}
          {%- if not items -%}Es läuft kein Timer.
          {%- else -%}
            {%- for t in items -%}
              {{ timer_name(t) }}: {{ 'pausiert, ' if t.state == 'paused' else "" }}noch {{ dauer(t.remaining) }}.{{ ' ' if not loop.last }}
            {%- endfor -%}
          {%- endif -%}
        '';
      };
    };
  };
}
