{ lib, ... }:
let
  r = lib.ha.remembrance;
  inherit (r) area callService secondsOf;

  # Durations without a number, as literal sentences that start a timer.
  # Against the number patterns they only win when said as is (an
  # exact sentence scores 100); otherwise "eine halbe Stunde" would become
  # "eine Stunde".
  fixedDurations = {
    "eine halbe Stunde" = 1800;
    "eine Viertelstunde" = 900;
    "eine Dreiviertelstunde" = 2700;
    "anderthalb Stunden" = 5400;
    "eine halbe Minute" = 30;
  };

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
    "<dauer>" = r.durationShapes "";
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

  fixedStartIntents = lib.listToAttrs (
    lib.imap1 (
      i: phrase:
      lib.nameValuePair "TimerStellenFest${toString i}" {
        sentences = [
          "Timer auf ${phrase}"
          "Stelle einen Timer auf ${phrase}"
          "Stelle einen {timer_label:label} Timer auf ${phrase}"
        ];
        inherit lists;
        script = {
          action = start fixedDurations.${phrase};
          speech.text = startSpeech;
        };
      }
    ) (lib.attrNames fixedDurations)
  );
  start =
    duration:
    callService "timer_start" {
      inherit duration area;
      label = "{{ label | default('') }}";
    };
  startSpeech = speak "{{ timer_name(t) }}{{ ' auf ' ~ dauer(t.duration) if t.label else '' }} - ab jetzt.";
in
{
  hass.voice.intents = fixedStartIntents // {
    TimerStellen = {
      sentences = expand [
        "Stelle einen Timer auf <dauer>"
        "Stelle einen {timer_label:label} Timer auf <dauer>"
        # A name only in this form: in the short form ("Nudel Timer auf …")
        # the unnamed pattern ties and wins.
        "Timer auf <dauer>"
        "<dauer> ab jetzt"
      ];
      inherit lists;
      script = {
        action = start "{{ ${secondsOf ""} }}";
        speech.text = startSpeech;
      };
    };

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
