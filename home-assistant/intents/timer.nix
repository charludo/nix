{ lib, ... }:
let
  inherit (lib.ha.voice) remembranceJinja silentAction;

  # Spoken durations, one sentence per shape: closest_intent expands each
  # pattern into at most 16 variants (`expansion_cap`), so alternations and
  # optionals inside one pattern get cut off. Fuzzy matching covers
  # "Minute"/"Minuten" and articles anyway. Each use fills its own slots:
  # a timer's new duration (no prefix), a change to it (`delta_`), or the
  # duration naming a timer (`set_`, see `timerShapes`).
  durationShapes = p: [
    "{timer_zahl:${p}minutes} Minuten"
    "{timer_zahl:${p}hours} Stunden"
    "{timer_zahl:${p}seconds} Sekunden"
    "{timer_zahl:${p}hours} Stunden und {timer_zahl:${p}minutes} Minuten"
    "{timer_zahl:${p}minutes} Minuten und {timer_zahl:${p}seconds} Sekunden"
  ];

  # 1 to 100 as digits and German words. HA's own number lists hold digits
  # only: closest_intent scores a spoken "eine" or "zwanzig" against those
  # and drops the sentence.
  germanNumber =
    n:
    let
      ones = [ "" "eins" "zwei" "drei" "vier" "fünf" "sechs" "sieben" "acht" "neun" ];
      teens = [ "zehn" "elf" "zwölf" "dreizehn" "vierzehn" "fünfzehn" "sechzehn" "siebzehn" "achtzehn" "neunzehn" ];
      tens = [ "" "" "zwanzig" "dreißig" "vierzig" "fünfzig" "sechzig" "siebzig" "achtzig" "neunzig" ];
      t = n / 10;
      o = lib.mod n 10;
    in
    if n == 1 then [ "eins" "ein" "eine" "einer" ]
    else if n < 10 then [ (builtins.elemAt ones n) ]
    else if n < 20 then [ (builtins.elemAt teens (n - 10)) ]
    else if n == 100 then [ "hundert" "einhundert" ]
    else if o == 0 then [ (builtins.elemAt tens t) ]
    else [ "${if o == 1 then "ein" else builtins.elemAt ones o}und${builtins.elemAt tens t}" ];
  # Durations without a number, as literal sentences that start a timer.
  # Against the number patterns above they only win when said as is (an
  # exact sentence scores 100); otherwise "eine halbe Stunde" would become
  # "eine Stunde".
  fixedDurations = {
    "eine halbe Stunde" = 1800;
    "eine Viertelstunde" = 900;
    "eine Dreiviertelstunde" = 2700;
    "anderthalb Stunden" = 5400;
    "eine halbe Minute" = 30;
  };

  numberValues = lib.concatMap (
    n:
    map (w: {
      "in" = w;
      out = n;
    }) ([ (toString n) ] ++ germanNumber n)
  ) (lib.range 1 100);

  # Jinja expression: the seconds a duration's slots add up to.
  secondsOf =
    p:
    "((${p}hours | default(0) | int) * 3600 + (${p}minutes | default(0) | int) * 60"
    + " + (${p}seconds | default(0) | int))";

  # "den Timer", "den 5-Minuten-Timer" (speech-to-text hyphens arrive as
  # spaces in closest_intent), "den Nudel-Timer". The label is its own
  # sentence, so the wildcard doesn't compete with a duration in one pattern.
  # Timers are named by minutes only; hours and seconds are rare enough.
  timerShapes = [
    "Timer"
    "{timer_zahl:set_minutes} Minuten Timer"
    "{timer_label:label} Timer"
  ];

  # Every sentence once per shape of each placeholder it contains.
  placeholders = {
    "<dauer>" = durationShapes "";
    # Changes in one unit only: "um eine Minute", "um 30 Sekunden".
    "<aenderung>" = lib.take 3 (durationShapes "delta_");
    "<timer>" = timerShapes;
  };
  expand =
    sentences:
    lib.foldlAttrs (
      acc: placeholder: shapes:
      lib.concatMap (
        s: if lib.hasInfix placeholder s then map (x: lib.replaceStrings [ placeholder ] [ x ] s) shapes else [ s ]
      ) acc
    ) sentences placeholders;

  # Lists are global per language, hence the prefixes.
  lists = {
    timer_label.wildcard = true;
    timer_zahl.values = numberValues;
  };

  area = "{{ preferred_area_id | default('') }}";

  # What was said about the timer, and where (only breaks ties). Unsaid
  # fields render empty or 0, which remembrance treats as not given.
  target = {
    label = "{{ label | default('') }}";
    duration = "{{ ${secondsOf "set_"} }}";
    inherit area;
  };

  # Call `service` and stop with its response, which the speech reads as
  # `action_response`.
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

  # Speech for a timer action: `ok` (Jinja; `t` is the timer) on success,
  # the shared answers otherwise.
  speak = ok: ''
    ${remembranceJinja}
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
    mkIntent ([ "<timer> um <aenderung> ${verb}" "${imperative} den <timer> um <aenderung>" ] ++ extra)
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
          action = callService "timer_start" {
            duration = fixedDurations.${phrase};
            label = "{{ label | default('') }}";
            inherit area;
          };
          speech.text = startSpeech;
        };
      }
    ) (lib.attrNames fixedDurations)
  );
  startSpeech = speak "{{ timer_name(t) }}{{ ' auf ' ~ dauer(t.duration) if t.label else '' }} - ab jetzt.";
in
{
  hass.remembrance.settings = {
    ring_script = "script.remembrance_ring";
    ring.timer = {
      interval = 20;
      limit = 120;
    };
  };

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
        action = callService "timer_start" {
          duration = "{{ ${secondsOf ""} }}";
          label = "{{ label | default('') }}";
          inherit area;
        };
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
          ${remembranceJinja}
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

    # Anything ringing (timers now, reminders and alarms later). Silent:
    # the ringing stopping is the answer.
    Stopp = silentAction {
      sentences = [
        "Stopp"
        "Stop"
        "Ist gut"
        "(Timer|Wecker) aus"
      ];
      script.action = callService "dismiss" { inherit area; };
    };

    # Ring again: what is ringing, else what rang last. No duration: the
    # configured snooze delay.
    NochMal = {
      sentences = expand [
        "In <dauer> noch mal"
        "Erinnere mich in <dauer> noch mal"
        "Schlummern"
      ];
      inherit lists;
      script = {
        action = callService "snooze" {
          delay = "{{ ${secondsOf ""} }}";
          inherit area;
        };
        speech.text = ''
          ${remembranceJinja}
          {%- set r = action_response -%}
          {%- if r.status == 'ok' -%}Okay, in {{ dauer(r['items'][0].remaining) }} noch mal.
          {%- else -%}Gerade gab es nichts, was ich wiederholen könnte.
          {%- endif -%}
        '';
      };
    };
  };
}
